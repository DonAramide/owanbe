"""
FastAPI RBAC sketch — Owanbe
Depends: OAuth2 / JWT middleware sets request.state.user = {"sub", "tenant_id", "roles": [...]}
"""

from __future__ import annotations

from typing import Annotated, Callable, Iterable

from fastapi import Depends, HTTPException, Request, status

ROLE_PERMISSIONS: dict[str, set[str]] = {
    "admin": {
        "admin:onboarding:queue",
        "admin:onboarding:review",
        "admin:vendor:suspend",
        "booking:read:own",
        "booking:read:vendor_scope",
        "tenant:read",
        "catalog:read",
    },
    "client": {
        "booking:create",
        "booking:read:own",
        "booking:update:own",
        "payment:initiate:own",
        "payment:read:own",
        "chat:thread:read",
        "chat:message:send",
        "tenant:read",
        "catalog:read",
    },
    "vendor": {
        "vendor:profile:write:own",
        "vendor:onboarding:submit",
        "vendor:package:write",
        "booking:read:vendor_scope",
        "booking:update:vendor_scope",
        "payout:read:vendor_scope",
        "chat:thread:read",
        "chat:message:send",
        "payment:read:own",
        "tenant:read",
        "catalog:read",
    },
}


def expand_permissions(roles: Iterable[str]) -> set[str]:
    out: set[str] = set()
    for r in roles or ():
        out |= ROLE_PERMISSIONS.get(r, set())
    return out


def get_permissions(request: Request) -> set[str]:
    user = getattr(request.state, "user", None) or {}
    return expand_permissions(user.get("roles") or [])


def require_permissions(*required: str):
    """Factory: Depends(require_permissions('booking:create'))"""

    async def dep(
        perms: Annotated[set[str], Depends(get_permissions)],
    ) -> None:
        missing = [p for p in required if p not in perms]
        if missing:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"code": "FORBIDDEN", "missing": missing},
            )

    return dep


# Usage:
# @router.post("/v1/bookings")
# async def create_booking(_: Annotated[None, Depends(require_permissions("booking:create"))]):
#     ...

