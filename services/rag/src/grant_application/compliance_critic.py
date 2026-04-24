import re
from typing import Literal, TypedDict

from packages.db.src.json_objects import GrantElement, GrantLongFormSection


class ComplianceIssue(TypedDict):
    requirement: str
    section_id: str
    section_title: str
    severity: Literal["HIGH", "MEDIUM", "LOW"]


class ComplianceSummary(TypedDict):
    is_compliant: bool
    severity: Literal["HIGH", "MEDIUM", "LOW"] | None
    checked_requirements: int
    missing_requirements: int
    high_count: int
    medium_count: int
    low_count: int
    missing_items: list[ComplianceIssue]


STOPWORDS = {
    "a",
    "an",
    "and",
    "as",
    "at",
    "be",
    "by",
    "for",
    "from",
    "in",
    "is",
    "of",
    "on",
    "or",
    "that",
    "the",
    "to",
    "with",
}


HIGH_SEVERITY_RE = re.compile(
    r"\b(irb|ethic|consent|hipaa|privacy|data sharing plan|human subjects|animal welfare|biosafety)\b",
    re.IGNORECASE,
)
MEDIUM_SEVERITY_RE = re.compile(
    r"\b(conflict of interest|reporting|data management|governance|regulatory|inclusion plan)\b",
    re.IGNORECASE,
)
COMPLIANCE_HINT_RE = re.compile(
    r"\b(compliance|regulatory|ethic|consent|privacy|irb|biosafety|human subjects|conflict of interest)\b",
    re.IGNORECASE,
)


def _normalize(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9\s]", " ", text.lower())).strip()


def _tokenize(text: str) -> set[str]:
    return {token for token in _normalize(text).split(" ") if token and token not in STOPWORDS and len(token) > 2}


def _determine_severity(requirement: str) -> Literal["HIGH", "MEDIUM", "LOW"]:
    if HIGH_SEVERITY_RE.search(requirement):
        return "HIGH"
    if MEDIUM_SEVERITY_RE.search(requirement):
        return "MEDIUM"
    return "LOW"


def _is_requirement_covered(requirement: str, application_text: str) -> bool:
    requirement_normalized = _normalize(requirement)
    app_normalized = _normalize(application_text)

    if requirement_normalized and requirement_normalized in app_normalized:
        return True

    req_tokens = _tokenize(requirement)
    if not req_tokens:
        return True

    app_tokens = _tokenize(application_text)
    matched = len(req_tokens.intersection(app_tokens))
    return matched / len(req_tokens) >= 0.6


def analyze_compliance_requirements(
    *,
    application_text: str,
    grant_sections: list[GrantLongFormSection | GrantElement],
) -> ComplianceSummary:
    issues: list[ComplianceIssue] = []
    checked_requirements = 0

    for section in grant_sections:
        requirements_raw = section.get("requirements", []) if isinstance(section, dict) else []
        if not isinstance(requirements_raw, list) or not requirements_raw:
            continue

        for requirement_entry in requirements_raw:
            if not isinstance(requirement_entry, dict):
                continue
            requirement = requirement_entry.get("requirement", "").strip()
            category = requirement_entry.get("category", "").strip().lower()
            if not requirement:
                continue

            if category != "compliance" and not COMPLIANCE_HINT_RE.search(requirement):
                continue

            checked_requirements += 1
            if _is_requirement_covered(requirement, application_text):
                continue

            issues.append(
                {
                    "requirement": requirement,
                    "section_id": str(section.get("id", "")),
                    "section_title": str(section.get("title", "Untitled Section")),
                    "severity": _determine_severity(requirement),
                }
            )

    high_count = sum(1 for issue in issues if issue["severity"] == "HIGH")
    medium_count = sum(1 for issue in issues if issue["severity"] == "MEDIUM")
    low_count = sum(1 for issue in issues if issue["severity"] == "LOW")

    severity: Literal["HIGH", "MEDIUM", "LOW"] | None = None
    if high_count > 0:
        severity = "HIGH"
    elif medium_count > 0:
        severity = "MEDIUM"
    elif low_count > 0:
        severity = "LOW"

    return {
        "is_compliant": len(issues) == 0,
        "severity": severity,
        "checked_requirements": checked_requirements,
        "missing_requirements": len(issues),
        "high_count": high_count,
        "medium_count": medium_count,
        "low_count": low_count,
        "missing_items": issues,
    }
