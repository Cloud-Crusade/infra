import json


def handler(event, context):
    # 대기열 stub — 실제 대기열/입장 토큰 로직은 후속(메인 이슈 sub).
    event_id = (event.get("pathParameters") or {}).get("event_id")
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps({"code": "WAITING", "message": "대기열 stub", "data": {"event_id": event_id}}),
    }
