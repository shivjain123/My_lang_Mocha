"""
from dataclasses import dataclass, field
from typing import Optional, List, TYPE_CHECKING

if TYPE_CHECKING:
    from __future__ import annotations

@dataclass
class ASTNode:
    kind: str = ""
    value: str = ""
    type_str: str = ""
    extra: str = ""
    int_val: int = 0
    real_val: float = 0.0
    imag_val: float = 0.0
    bool_val: bool = False
    left: Optional['ASTNode'] = None
    right: Optional['ASTNode'] = None
    condition: Optional['ASTNode'] = None
    body: List['ASTNode'] = field(default_factory=list)
    children: List['ASTNode'] = field(default_factory=list)
    params: List['ASTNode'] = field(default_factory=list)
    args: List['ASTNode'] = field(default_factory=list)
    else_body: List['ASTNode'] = field(default_factory=list)
    else_ifs: List['ASTNode'] = field(default_factory=list)
    cases: List['ASTNode'] = field(default_factory=list)
    flag1: bool = False
    flag2: bool = False
    is_variadic: bool = False
    line: int = 0
    col: int = 0
"""