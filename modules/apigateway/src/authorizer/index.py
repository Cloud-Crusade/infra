def handler(event, context):
    # 예약 경로 authorizer — Reservation 헤더 존재만 검사(서명 검증 없음).
    # 없으면 isAuthorized=False → API Gateway 가 403 반환.
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    return {"isAuthorized": "reservation" in headers}
