from datetime import datetime

from langchain_core.runnables import RunnableConfig
from langgraph.types import StreamWriter

from onyx.agents.agent_search.kb_search.graph_utils import get_near_empty_step_results
from onyx.agents.agent_search.kb_search.graph_utils import stream_close_step_answer
from onyx.agents.agent_search.kb_search.graph_utils import (
    stream_write_step_answer_explicit,
)
from onyx.agents.agent_search.kb_search.states import MainState
from onyx.agents.agent_search.kb_search.states import ResultsDataUpdate
from onyx.agents.agent_search.shared_graph_utils.utils import (
    get_langgraph_node_log_string,
)
from onyx.agents.agent_search.shared_graph_utils.utils import write_custom_event
from onyx.chat.models import SubQueryPiece
from onyx.db.document import get_base_llm_doc_information
from onyx.db.engine import get_session_with_current_tenant
from onyx.utils.logger import setup_logger


logger = setup_logger()


def _get_formated_source_reference_results(
    source_document_results: list[str] | None,
) -> str | None:
    """
    Generate reference results from the query results data string.
    """

    if source_document_results is None:
        return None

    # get all entities that correspond to an Onyx document
    document_ids = source_document_results

    with get_session_with_current_tenant() as session:
        llm_doc_information_results = get_base_llm_doc_information(
            session, document_ids
        )

    if len(llm_doc_information_results) == 0:
        return ""

    return (
        f"\n \n Here are {len(llm_doc_information_results)} supporting documents or examples: \n \n "
        + " \n \n ".join(llm_doc_information_results)
    )


def process_kg_only_answers(
    state: MainState, config: RunnableConfig, writer: StreamWriter = lambda _: None
) -> ResultsDataUpdate:
    """
    LangGraph node to start the agentic search process.
    """

    _KG_STEP_NR = 4

    node_start_time = datetime.now()

    query_results = state.sql_query_results
    source_document_results = state.source_document_results

    # we use this stream write explicitly

    write_custom_event(
        "subqueries",
        SubQueryPiece(
            sub_query="Formatted References",
            level=0,
            level_question_num=_KG_STEP_NR,
            query_id=1,
        ),
        writer,
    )

    query_results_list = []

    if query_results:
        for query_result in query_results:
            query_results_list.append(
                str(query_result).replace("::", ":: ").capitalize()
            )
    else:
        raise ValueError("No query results were found")

    query_results_data_str = "\n".join(query_results_list)

    source_reference_result_str = _get_formated_source_reference_results(
        source_document_results
    )

    ## STEP 4 - same components as Step 1

    step_answer = (
        "No further research is needed, the answer is derived from the knowledge graph."
    )

    stream_write_step_answer_explicit(writer, step_nr=_KG_STEP_NR, answer=step_answer)

    stream_close_step_answer(writer, _KG_STEP_NR)

    return ResultsDataUpdate(
        query_results_data_str=query_results_data_str,
        individualized_query_results_data_str="",
        reference_results_str=source_reference_result_str,
        log_messages=[
            get_langgraph_node_log_string(
                graph_component="main",
                node_name="kg query results data processing",
                node_start_time=node_start_time,
            )
        ],
        step_results=[
            get_near_empty_step_results(
                step_number=_KG_STEP_NR, step_answer=step_answer
            )
        ],
    )
