from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Dict
import json
import os

from .redis_client import cache_get, cache_set


def is_demo_payment_enabled() -> bool:
    """
    MVP: simulated checkout (no PSP) is ON by default so Guest→Listen→REP and Artist→Artist+ work in the app.
    Set env DEMO_PAYMENT_ENABLED=false when real billing is integrated.
    """
    return os.environ.get("DEMO_PAYMENT_ENABLED", "true").strip().lower() in ("1", "true", "yes")
from .auth_integration import get_current_user
from .models import User

router = APIRouter(prefix="/config", tags=["config"])


UI_CONFIG_REDIS_KEY = "app_config:ui_v1"

# NOIZE Listen — primary paid tier (INR). Amounts mirror app `upgrade_screen` (paise = INR × 100).
NOIZE_LISTEN_INR_MONTHLY = 149
NOIZE_LISTEN_MONTHLY_PAISE = 149_00  # 149 INR
NOIZE_LISTEN_YEARLY_PAISE = 1499_00  # ₹1499/yr list price in app
NOIZE_LISTEN_ROLE = "main_revenue_generator"
NOIZE_LISTEN_MECHANIC = "Drives stream revenue distribution to rights holders."

# NOIZE REP — next phase after Listen (INR). Engagement / growth / referrals / token economy.
NOIZE_REP_INR_MONTHLY = 399
NOIZE_REP_MONTHLY_PAISE = 399_00
NOIZE_REP_YEARLY_PAISE = 3999_00
NOIZE_REP_ROLE = "controlled_growth_engine"
NOIZE_REP_PURPOSE = "Growth + referrals"
NOIZE_REP_MECHANIC = "Task and referral earnings from reward pool; token caps limit velocity."

# NOIZE Artist (free channel) / Artist+ (paid). Not the same product as listener NOIZE REP.
NOIZE_ARTIST_PLUS_STANDARD_PAISE = 299_00  # ₹299/mo
NOIZE_ARTIST_PLUS_PRO_PAISE = 599_00  # ₹599/mo

_fallback_ui_config = {
    "story_title": "Your Story",
    "greetings": {
        "morning": "Good morning",
        "afternoon": "Good afternoon",
        "evening": "Good evening",
        "night": "Good night",
    },
}


class UiConfig(BaseModel):
    story_title: str = Field(default="Your Story", max_length=64)
    greetings: Dict[str, str] = Field(default_factory=dict)


async def _get_ui_config() -> dict:
    """Get UI config from Redis, fall back to in-memory defaults."""
    try:
        cached = await cache_get(UI_CONFIG_REDIS_KEY)
        if cached:
            parsed = json.loads(cached)
            if isinstance(parsed, dict):
                # Shallow-merge with defaults so missing keys don't break clients.
                merged = {**_fallback_ui_config, **parsed}
                merged["greetings"] = {
                    **_fallback_ui_config.get("greetings", {}),
                    **(parsed.get("greetings") or {}),
                }
                return merged
    except Exception as e:
        # Redis might be down; fail open with defaults.
        print(f"UI config cache_get failed: {e}")
    return _fallback_ui_config


async def _set_ui_config(cfg: dict) -> dict:
    """Persist UI config to Redis (best-effort) and update in-memory fallback."""
    global _fallback_ui_config
    merged = {**_fallback_ui_config, **cfg}
    merged["greetings"] = {
        **_fallback_ui_config.get("greetings", {}),
        **(cfg.get("greetings") or {}),
    }
    _fallback_ui_config = merged
    try:
        await cache_set(UI_CONFIG_REDIS_KEY, merged, expiry_seconds=60 * 60 * 24 * 365)
    except Exception as e:
        print(f"UI config cache_set failed: {e}")
    return merged


@router.get("/ui", response_model=UiConfig)
async def get_ui_config():
    return await _get_ui_config()


@router.get("/subscription-tiers")
async def get_subscription_tiers():
    """
    Public product metadata for subscription tiers (billing UI, admin, analytics).
    NOIZE Listen / REP: listener subscriptions. NOIZE Artist / Artist+: channel creator tiers (upload vs monetisation).
    """
    return {
        "currency": "INR",
        "minor_unit": "paise",
        "demo_payment_enabled": is_demo_payment_enabled(),
        "listen": {
            "id": "listen",
            "name": "NOIZE Listen",
            "role": NOIZE_LISTEN_ROLE,
            "mechanic": NOIZE_LISTEN_MECHANIC,
            "monthly_amount_paise": NOIZE_LISTEN_MONTHLY_PAISE,
            "yearly_amount_paise": NOIZE_LISTEN_YEARLY_PAISE,
            "inr_per_month": NOIZE_LISTEN_INR_MONTHLY,
            "features": [
                "ad_free",
                "unlimited_skips",
                "offline_downloads",
                "full_catalog_access",
                "stream_revenue_distribution",
            ],
        },
        "rep": {
            "id": "rep",
            "name": "NOIZE REP",
            "role": NOIZE_REP_ROLE,
            "purpose": NOIZE_REP_PURPOSE,
            "mechanic": NOIZE_REP_MECHANIC,
            "phase": "after_listen",
            "monthly_amount_paise": NOIZE_REP_MONTHLY_PAISE,
            "yearly_amount_paise": NOIZE_REP_YEARLY_PAISE,
            "inr_per_month": NOIZE_REP_INR_MONTHLY,
            "features": [
                "referral_system",
                "task_based_earning",
                "token_dashboard",
            ],
            "token_limits": {
                "daily": 50,
                "monthly_min": 800,
                "monthly_max": 1200,
            },
            "earnings_model": "reward_pool_variable",
        },
        "artist": {
            "id": "artist",
            "name": "NOIZE Artist",
            "tier": "free",
            "features": [
                "upload_music",
                "channel_profile",
                "basic_stats",
            ],
        },
        "artist_plus": {
            "id": "artist_plus",
            "name": "NOIZE Artist+",
            "role": "channel_monetisation_addon",
            "monthly_tiers_paise": {
                "standard": NOIZE_ARTIST_PLUS_STANDARD_PAISE,
                "pro": NOIZE_ARTIST_PLUS_PRO_PAISE,
            },
            "inr_per_month_range": [299, 599],
            "features": [
                "fan_tipping",
                "merchandise",
                "campaign_creation",
            ],
            "events_module": {
                "artist_plus_only": True,
                "event_info": True,
                "external_ticket_link": True,
                "listing_on_profile": True,
            },
        },
        "influencer": {
            "id": "influencer",
            "name": "NOIZE Creator",
            "monthly_amount_paise": 129900,
            "yearly_amount_paise": 1299900,
        },
    }


class UiConfigUpdate(BaseModel):
    story_title: str | None = Field(default=None, max_length=64)
    greetings: Dict[str, str] | None = None


async def _require_admin(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user


@router.put("/ui", response_model=UiConfig)
async def update_ui_config(payload: UiConfigUpdate, admin: User = Depends(_require_admin)):
    # Clean inputs
    cfg: dict = {}
    if payload.story_title is not None:
        cfg["story_title"] = payload.story_title.strip() or _fallback_ui_config["story_title"]
    if payload.greetings is not None:
        cleaned = {}
        for k, v in payload.greetings.items():
            if not isinstance(k, str):
                continue
            kk = k.strip().lower()
            if not kk:
                continue
            vv = (v or "").strip()
            if not vv:
                continue
            cleaned[kk] = vv
        cfg["greetings"] = cleaned
    return await _set_ui_config(cfg)

