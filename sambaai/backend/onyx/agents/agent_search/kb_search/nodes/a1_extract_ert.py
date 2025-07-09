from datetime import datetime
from typing import cast

from langchain_core.messages import HumanMessage
from langchain_core.runnables import RunnableConfig
from langgraph.types import StreamWriter
from pydantic import ValidationError

from onyx.agents.agent_search.kb_search.graph_utils import get_near_empty_step_results
from onyx.agents.agent_search.kb_search.graph_utils import stream_close_step_answer
from onyx.agents.agent_search.kb_search.graph_utils import stream_write_step_activities
from onyx.agents.agent_search.kb_search.graph_utils import (
    stream_write_step_answer_explicit,
)
from onyx.agents.agent_search.kb_search.graph_utils import stream_write_step_structure
from onyx.agents.agent_search.kb_search.models import KGQuestionEntityExtractionResult
from onyx.agents.agent_search.kb_search.models import (
    KGQuestionRelationshipExtractionResult,
)
from onyx.agents.agent_search.kb_search.states import ERTExtractionUpdate
from onyx.agents.agent_search.kb_search.states import MainState
from onyx.agents.agent_search.models import GraphConfig
from onyx.agents.agent_search.shared_graph_utils.utils import (
    get_langgraph_node_log_string,
)
from onyx.configs.kg_configs import KG_ENTITY_EXTRACTION_TIMEOUT
from onyx.configs.kg_configs import KG_RELATIONSHIP_EXTRACTION_TIMEOUT
from onyx.db.engine import get_session_with_current_tenant
from onyx.db.kg_temp_view import create_views
from onyx.db.kg_temp_view import get_user_view_names
from onyx.db.relationships import get_allowed_relationship_type_pairs
from onyx.kg.extractions.extraction_processing import get_entity_types_str
from onyx.kg.extractions.extraction_processing import get_relationship_types_str
from onyx.prompts.kg_prompts import QUERY_ENTITY_EXTRACTION_PROMPT
from onyx.prompts.kg_prompts import QUERY_RELATIONSHIP_EXTRACTION_PROMPT
from onyx.utils.logger import setup_logger
from onyx.utils.threadpool_concurrency import run_with_timeout

logger = setup_logger()


def extract_ert(
    state: MainState, config: RunnableConfig, writer: StreamWriter = lambda _: None
) -> ERTExtractionUpdate:
    """
    LangGraph node to start the agentic search process.
    """

    # recheck KG enablement at outset KG graph

    if not config["metadata"]["config"].behavior.kg_config_settings.KG_ENABLED:
        logger.error("KG approach is not enabled, the KG agent flow cannot run.")
        raise ValueError("KG approach is not enabled, the KG agent flow cannot run.")

    _KG_STEP_NR = 1

    node_start_time = datetime.now()

    graph_config = cast(GraphConfig, config["metadata"]["config"])

    if graph_config.tooling.search_tool is None:
        raise ValueError("Search tool is not set")
    elif graph_config.tooling.search_tool.user is None:
        raise ValueError("User is not set")
    else:
        user_email = graph_config.tooling.search_tool.user.email
        user_name = user_email.split("@")[0] or "unknown"

    # first four lines duplicates from generate_initial_answer
    question = graph_config.inputs.prompt_builder.raw_user_query
    today_date = datetime.now().strftime("%A, %Y-%m-%d")

    all_entity_types = get_entity_types_str(active=True)
    all_relationship_types = get_relationship_types_str(active=True)

    # Stream structure of substeps out to the UI
    stream_write_step_structure(writer)

    # Now specify core activities in the step (step 1)
    stream_write_step_activities(writer, _KG_STEP_NR)

    # Create temporary views. TODO: move into parallel step, if ultimately materialized
    kg_views = get_user_view_names(user_email)
    with get_session_with_current_tenant() as db_session:
        create_views(
            db_session,
            user_email=user_email,
            allowed_docs_view_name=kg_views.allowed_docs_view_name,
            kg_relationships_view_name=kg_views.kg_relationships_view_name,
            kg_entity_view_name=kg_views.kg_entity_view_name,
        )

    ### get the entities, terms, and filters

    query_extraction_pre_prompt = QUERY_ENTITY_EXTRACTION_PROMPT.format(
        entity_types=all_entity_types,
        relationship_types=all_relationship_types,
    )

    query_extraction_prompt = (
        query_extraction_pre_prompt.replace("---content---", question)
        .replace("---today_date---", today_date)
        .replace("---user_name---", f"EMPLOYEE:{user_name}")
        .replace("{{", "{")
        .replace("}}", "}")
    )

    msg = [
        HumanMessage(
            content=query_extraction_prompt,
        )
    ]
    primary_llm = graph_config.tooling.primary_llm
    # Grader
    try:
        llm_response = run_with_timeout(
            KG_ENTITY_EXTRACTION_TIMEOUT,
            primary_llm.invoke,
            prompt=msg,
            timeout_override=15,
            max_tokens=300,
        )

        cleaned_response = (
            str(llm_response.content)
            .replace("{{", "{")
            .replace("}}", "}")
            .replace("```json\n", "")
            .replace("\n```", "")
            .replace("\n", "")
        )
        first_bracket = cleaned_response.find("{")
        last_bracket = cleaned_response.rfind("}")
        cleaned_response = cleaned_response[first_bracket : last_bracket + 1]

        try:
            entity_extraction_result = (
                KGQuestionEntityExtractionResult.model_validate_json(cleaned_response)
            )
        except ValidationError:
            logger.error("Failed to parse LLM response as JSON in Entity Extraction")
            entity_extraction_result = KGQuestionEntityExtractionResult(
                entities=[], time_filter=""
            )
    except Exception as e:
        logger.error(f"Error in extract_ert: {e}")
        entity_extraction_result = KGQuestionEntityExtractionResult(
            entities=[], time_filter=""
        )

    # remove the attribute filters from the entities to for the purpose of the relationship
    entities_no_attributes = [
        entity.split("--")[0] for entity in entity_extraction_result.entities
    ]
    ert_entities_string = f"Entities: {entities_no_attributes}\n"

    ### get the relationships

    # find the relationship types that match the extracted entity types

    with get_session_with_current_tenant() as db_session:
        allowed_relationship_pairs = get_allowed_relationship_type_pairs(
            db_session, entity_extraction_result.entities
        )

    query_relationship_extraction_prompt = (
        QUERY_RELATIONSHIP_EXTRACTION_PROMPT.replace("---question---", question)
        .replace("---today_date---", today_date)
        .replace(
            "---relationship_type_options---",
            "  - " + "\n  - ".join(allowed_relationship_pairs),
        )
        .replace("---identified_entities---", ert_entities_string)
        .replace("---entity_types---", all_entity_types)
        .replace("{{", "{")
        .replace("}}", "}")
    )

    msg = [
        HumanMessage(
            content=query_relationship_extraction_prompt,
        )
    ]
    primary_llm = graph_config.tooling.primary_llm
    # Grader
    try:
        llm_response = run_with_timeout(
            KG_RELATIONSHIP_EXTRACTION_TIMEOUT,
            primary_llm.invoke,
            prompt=msg,
            timeout_override=15,
            max_tokens=300,
        )

        cleaned_response = (
            str(llm_response.content)
            .replace("{{", "{")
            .replace("}}", "}")
            .replace("```json\n", "")
            .replace("\n```", "")
            .replace("\n", "")
        )
        first_bracket = cleaned_response.find("{")
        last_bracket = cleaned_response.rfind("}")
        cleaned_response = cleaned_response[first_bracket : last_bracket + 1]
        cleaned_response = cleaned_response.replace("{{", '{"')
        cleaned_response = cleaned_response.replace("}}", '"}')

        try:
            relationship_extraction_result = (
                KGQuestionRelationshipExtractionResult.model_validate_json(
                    cleaned_response
                )
            )
        except ValidationError:
            logger.error(
                "Failed to parse LLM response as JSON in Relationship Extraction"
            )
            relationship_extraction_result = KGQuestionRelationshipExtractionResult(
                relationships=[],
            )
    except Exception as e:
        logger.error(f"Error in extract_ert: {e}")
        relationship_extraction_result = KGQuestionRelationshipExtractionResult(
            relationships=[],
        )

    ## STEP 1
    # Stream answer pieces out to the UI for Step 1

    extracted_entity_string = " \n ".join(
        [x.split("--")[0] for x in entity_extraction_result.entities]
    )
    extracted_relationship_string = " \n ".join(
        relationship_extraction_result.relationships
    )

    step_answer = f"""Entities and relationships have been extracted from query - \n \
Entities: {extracted_entity_string} - \n Relationships: {extracted_relationship_string}"""

    stream_write_step_answer_explicit(writer, step_nr=1, answer=step_answer)

    # Finish Step 1
    stream_close_step_answer(writer, _KG_STEP_NR)

    return ERTExtractionUpdate(
        entities_types_str=all_entity_types,
        relationship_types_str=all_relationship_types,
        extracted_entities_w_attributes=entity_extraction_result.entities,
        extracted_entities_no_attributes=entities_no_attributes,
        extracted_relationships=relationship_extraction_result.relationships,
        time_filter=entity_extraction_result.time_filter,
        kg_doc_temp_view_name=kg_views.allowed_docs_view_name,
        kg_rel_temp_view_name=kg_views.kg_relationships_view_name,
        kg_entity_temp_view_name=kg_views.kg_entity_view_name,
        log_messages=[
            get_langgraph_node_log_string(
                graph_component="main",
                node_name="extract entities terms",
                node_start_time=node_start_time,
            )
        ],
        step_results=[
            get_near_empty_step_results(
                step_number=_KG_STEP_NR,
                step_answer=step_answer,
                verified_reranked_documents=[],
            )
        ],
    )
