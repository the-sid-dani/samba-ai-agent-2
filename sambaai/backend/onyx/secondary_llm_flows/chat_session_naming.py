from onyx.chat.chat_utils import combine_message_chain
from onyx.configs.chat_configs import LANGUAGE_CHAT_NAMING_HINT
from onyx.configs.model_configs import GEN_AI_HISTORY_CUTOFF
from onyx.db.models import ChatMessage
from onyx.db.search_settings import get_multilingual_expansion
from onyx.llm.interfaces import LLM
from onyx.llm.utils import dict_based_prompt_to_langchain_prompt
from onyx.llm.utils import message_to_string
from onyx.prompts.chat_prompts import CHAT_NAMING
from onyx.utils.logger import setup_logger

logger = setup_logger()


def get_renamed_conversation_name(
    full_history: list[ChatMessage],
    llm: LLM,
    chat_session_id: str | None = None,
) -> str:
    history_str = combine_message_chain(
        messages=full_history, token_limit=GEN_AI_HISTORY_CUTOFF
    )

    language_hint = (
        f"\n{LANGUAGE_CHAT_NAMING_HINT.strip()}"
        if bool(get_multilingual_expansion())
        else ""
    )

    prompt_msgs = [
        {
            "role": "user",
            "content": CHAT_NAMING.format(
                language_hint_or_empty=language_hint, chat_history=history_str
            ),
        },
    ]

    filled_llm_prompt = dict_based_prompt_to_langchain_prompt(prompt_msgs)
    
    metadata = {}
    if chat_session_id:
        chat_session_id = str(chat_session_id)
        logger.debug(f"Title generation for session: {chat_session_id}")
        
        metadata = {
            "session_id": chat_session_id,
            "trace_id": f"chat-session-{chat_session_id}",
            "generation_name": "chat_title_generation",
            "tags": ["samba-ai", "chat", "title-generation", "onyx"],
        }
    
    new_name_raw = message_to_string(llm.invoke(filled_llm_prompt, metadata=metadata))

    new_name = new_name_raw.strip().strip(' "')

    logger.debug(f"New Session Name: {new_name} for session: {chat_session_id}")

    return new_name
