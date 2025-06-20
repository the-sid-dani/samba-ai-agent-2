# Slack Bot Name Configuration Investigation

## Summary

After investigating the Onyx/SambaAI codebase, I've found that the bot name configuration is **already flexible** and does not require code changes. The bot's display name is determined dynamically from the Slack API based on the configured Slack app settings.

## Key Findings

### 1. Bot Name Detection is Dynamic
- The bot name displayed to users comes from the Slack app configuration (via Slack's API)
- In `listener.py` (lines 475-480), the bot name is fetched dynamically:
  ```python
  user_info = socket_client.web_client.users_info(user=bot_user_id)
  if user_info["ok"]:
      bot_name = user_info["user"]["real_name"] or user_info["user"]["name"]
      socket_client.bot_name = bot_name
  ```
- This means the bot will automatically use whatever name is configured in the Slack app

### 2. Mention Detection Uses Bot ID, Not Name
- The bot detects mentions using the bot's user ID from Slack, not a hardcoded name
- In `listener.py` (lines 669-670, 839-841):
  ```python
  if bot_token_user_id and f"<@{bot_token_user_id}>" in msg:
      is_tagged = True
  ```
- This means @sambaai mentions will work automatically when the Slack app is configured with that name

### 3. Hardcoded "OnyxBot" References
Found hardcoded references in the following locations:

#### User-Visible Error Messages:
1. **utils.py:102**: "OnyxBot has reached the message limit"
2. **utils.py:204**: "There was an error displaying all of the Onyx answers"

#### Internal Log Messages (not user-visible):
- **listener.py:680**: "Ignoring message from OnyxBot (self-message)"
- **listener.py:751**: "Received OnyxBot command without channel"
- **listener.py:758**: "Cannot respond to OnyxBot command without sender"
- **listener.py:844**: "User tagged OnyxBot"

#### Code Comments:
- **models.py:15-17**: Comments mentioning "@OnyxBot" and "/OnyxBot"
- **listener.py:683**: Comment about "@OnyxBot"

## Minimal Changes Required

### Required Changes (User-Visible):
1. **utils.py:102**: Change "OnyxBot has reached the message limit" to use dynamic bot name or generic "The bot"
2. **utils.py:204**: Change "Onyx answers" to "answers" or "bot responses"

### Optional Changes (Internal/Cosmetic):
1. Update internal log messages to use `client.bot_name` instead of hardcoded "OnyxBot"
2. Update code comments to be more generic (e.g., "the bot" instead of "OnyxBot")

## Configuration Process

To make the bot respond to @sambaai:

1. **Create Slack App** with proper manifest:
   ```yaml
   display_information:
     name: SambaAI
     description: Your AI assistant
   features:
     bot_user:
       display_name: SambaAI
       always_online: true
   ```

2. **Configure OAuth Scopes** as specified in Task 13

3. **Add tokens to environment**:
   - `DANSWER_BOT_SLACK_APP_TOKEN`
   - `DANSWER_BOT_SLACK_BOT_TOKEN`

4. **No code changes required** for basic functionality

## Recommendation

The Onyx codebase is already well-designed to support different bot names through Slack app configuration. Only minimal changes to error messages are truly necessary for a complete rebrand. The bot will automatically:
- Respond to @sambaai mentions
- Show "SambaAI" as the bot name in Slack
- Detect mentions using the configured bot's ID

The main work is in:
1. Creating the Slack app with SambaAI branding (Task 13)
2. Fixing the two user-visible error messages
3. Optionally updating internal references for consistency