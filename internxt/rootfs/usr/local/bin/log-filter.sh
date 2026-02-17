#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
#
# Log filter wrapper for Internxt WebDAV server
# Filters and formats JSON logs to make them more readable
#
# Modes:
# - quiet: Only errors and warnings
# - normal: Important messages, no verbose WebDAV operations

FILTER_MODE="${LOG_FILTER_MODE:-normal}"

while IFS= read -r line; do
    # Try to parse as JSON
    if level=$(echo "$line" | jq -r '.level // empty' 2>/dev/null); then
        message=$(echo "$line" | jq -r '.message // empty' 2>/dev/null)

        # In quiet mode, only show errors and warnings
        if [[ "$FILTER_MODE" == "quiet" ]]; then
            if [[ "$level" != "error" && "$level" != "warn" && "$level" != "warning" ]]; then
                continue
            fi
        fi

        # Skip verbose WebDAV request logs (info level)
        if [[ "$level" == "info" && "$message" == "WebDav request received"* ]]; then
            continue
        fi

        # Skip duplicate "already exists" info messages (keep errors though)
        if [[ "$level" == "info" && "$message" == *"already exists"* ]]; then
            continue
        fi

        # Format the message based on level
        case "$level" in
            error)
                # Show errors but make them concise (first line only)
                error_msg=$(echo "$message" | head -n1)
                bashio::log.error "$error_msg"
                ;;
            warn|warning)
                bashio::log.warning "$message"
                ;;
            info)
                # Skip verbose operation logs
                if [[ "$message" == *"[MKCOL]"* ]] || \
                   [[ "$message" == *"[PROPFIND]"* ]] || \
                   [[ "$message" == *"[GET]"* ]] || \
                   [[ "$message" == *"[PUT]"* ]] || \
                   [[ "$message" == *"[DELETE]"* ]] || \
                   [[ "$message" == *"[COPY]"* ]] || \
                   [[ "$message" == *"[MOVE]"* ]]; then
                    continue
                fi
                bashio::log.info "$message"
                ;;
            debug)
                # Skip debug in quiet mode
                if [[ "$FILTER_MODE" != "quiet" ]]; then
                    bashio::log.debug "$message"
                fi
                ;;
            *)
                # Unknown level, print as-is (unless in quiet mode)
                if [[ "$FILTER_MODE" != "quiet" ]]; then
                    bashio::log.info "$message"
                fi
                ;;
        esac
    else
        # Not JSON, print directly (unless in quiet mode)
        if [[ "$FILTER_MODE" != "quiet" ]]; then
            bashio::log.info "$line"
        fi
    fi
done
