import time
from collections.abc import Generator
from datetime import datetime
from datetime import timezone
from http import HTTPStatus

from office365.graph_client import GraphClient  # type: ignore

from onyx.connectors.interfaces import SecondsSinceUnixEpoch
from onyx.connectors.teams.models import Message


def retry(
    graph_client: GraphClient,
    request_url: str,
) -> dict:
    MAX_RETRIES = 10
    retry_number = 0

    while retry_number < MAX_RETRIES:
        response = graph_client.execute_request_direct(request_url)
        if response.ok:
            json = response.json()
            if not isinstance(json, dict):
                raise RuntimeError(f"Expected a JSON object, instead got {json=}")

            return json

        if response.status_code == int(HTTPStatus.TOO_MANY_REQUESTS):
            retry_number += 1

            cooldown = int(response.headers.get("Retry-After", 10))
            time.sleep(cooldown)

            continue

        response.raise_for_status()

    raise RuntimeError(
        f"Max number of retries for hitting {request_url=} exceeded; unable to fetch data"
    )


def get_next_url(
    graph_client: GraphClient,
    json_response: dict,
) -> str | None:
    next_url = json_response.get("@odata.nextLink")

    if not next_url:
        return None

    if not isinstance(next_url, str):
        raise RuntimeError(
            f"Expected a string for the `@odata.nextUrl`, instead got {next_url=}"
        )

    return next_url.removeprefix(graph_client.service_root_url()).removeprefix("/")


def fetch_messages(
    graph_client: GraphClient,
    team_id: str,
    channel_id: str,
    start: SecondsSinceUnixEpoch,
) -> Generator[Message]:
    startfmt = datetime.fromtimestamp(start, tz=timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )

    initial_request_url = (
        f"teams/{team_id}/channels/{channel_id}/messages/delta"
        f"?$filter=lastModifiedDateTime gt {startfmt}"
    )

    request_url: str | None = initial_request_url

    while request_url:
        json_response = retry(graph_client=graph_client, request_url=request_url)

        for value in json_response.get("value", []):
            yield Message(**value)

        request_url = get_next_url(
            graph_client=graph_client, json_response=json_response
        )


def fetch_replies(
    graph_client: GraphClient,
    team_id: str,
    channel_id: str,
    root_message_id: str,
) -> Generator[Message]:
    initial_request_url = (
        f"teams/{team_id}/channels/{channel_id}/messages/{root_message_id}/replies"
    )

    request_url: str | None = initial_request_url

    while request_url:
        json_response = retry(graph_client=graph_client, request_url=request_url)

        for value in json_response.get("value", []):
            yield Message(**value)

        request_url = get_next_url(
            graph_client=graph_client, json_response=json_response
        )
