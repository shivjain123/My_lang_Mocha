function mocha_str_toupper_ffi(s: str) -> str native mocha_str_toupper;
function mocha_str_tolower_ffi(s: str) -> str native mocha_str_tolower;
function c_isalpha(c: str) -> int native mocha_wrap_isalpha_str;
function c_isdigit(c: str) -> int native mocha_wrap_isdigit_str;

extend str {

    function toInt() -> int {
        return 0;
    };

    function toFloat() -> float {
        return 0.0;
    };

    function startsWith(prefix: str) -> bool {
        var pLen: int = prefix.length;
        if (pLen > this.length) {
            return false;
        };
        var i: int = 0;
        while (i < pLen) {
            if (str(this.charAt(i)) != str(prefix.charAt(i))) {
                return false;
            };
            i = i + 1;
        };
        return true;
    };

    function endsWith(suffix: str) -> bool {
        var sLen: int = suffix.length;
        var tLen: int = this.length;
        if (sLen > tLen) {
            return false;
        };
        var offset: int = tLen - sLen;
        var i: int = 0;
        while (i < sLen) {
            if (str(this.charAt(offset + i)) != str(suffix.charAt(i))) {
                return false;
            };
            i = i + 1;
        };
        return true;
    };

    function indexOf(sub: str) -> int {
        var subLen: int = sub.length;
        var tLen: int = this.length;
        var i: int = 0;
        while (i < tLen - subLen + 1) {
            var j: int = 0;
            var found: bool = true;
            while (j < subLen) {
                if (str(this.charAt(i + j)) != str(sub.charAt(j))) {
                    found = false;
                };
                j = j + 1;
            };
            if (found) {
                return i;
            };
            i = i + 1;
        };
        return -1;
    };

    function contains(sub: str) -> bool {
        return this.indexOf(sub) != -1;
    };

    function reverse() -> str {
        var result: str = "";
        var i: int = this.length - 1;
        while (i >= 0) {
            result = result + str(this.charAt(i));
            i = i - 1;
        };
        return result;
    };

    function isPalindrome() -> bool {
        return this == this.reverse();
    };

    function occurs(sub: str) -> int {
        var total: int = 0;
        var i: int = 0;
        var subLen: int = sub.length;
        var tLen: int = this.length;
        while (i < tLen - subLen + 1) {
            var j: int = 0;
            var found: bool = true;
            while (j < subLen) {
                if (str(this.charAt(i + j)) != str(sub.charAt(j))) {
                    found = false;
                };
                j = j + 1;
            };
            if (found) {
                total = total + 1;
                i = i + subLen;
            };
            if (!found) {
                i = i + 1;
            };
        };
        return total;
    };

    function trimLeft() -> str {
        var i: int = 0;
        var tLen: int = this.length;
        while (i < tLen) {
            var c: str = str(this.charAt(i));
            if (c != " " && c != "\t" && c != "\n") {
                break;
            };
            i = i + 1;
        };
        var result: str = "";
        while (i < tLen) {
            result = result + str(this.charAt(i));
            i = i + 1;
        };
        return result;
    };

    function trimRight() -> str {
        var i: int = this.length - 1;
        while (i >= 0) {
            var c: str = str(this.charAt(i));
            if (c != " " && c != "\t" && c != "\n") {
                break;
            };
            i = i - 1;
        };
        var result: str = "";
        var j: int = 0;
        while (j <= i) {
            result = result + str(this.charAt(j));
            j = j + 1;
        };
        return result;
    };

    function rip() -> str {
        return this.trimLeft().trimRight();
    };

    function substring(startIdx: int, endIdx: int) -> str {
        var result: str = "";
        var i: int = startIdx;
        while (i <= endIdx) {
            result = result + str(this.charAt(i));
            i = i + 1;
        };
        return result;
    };

    function replace(oldStr: str, newStr: str, occur: int) -> str {
        var result: str = "";
        var i: int = 0;
        var tLen: int = this.length;
        var oldLen: int = oldStr.length;
        var replaced: int = 0;
        while (i < tLen) {
            if (replaced < occur) {
                var j: int = 0;
                var found: bool = true;
                while (j < oldLen) {
                    if (i + j >= tLen) {
                        found = false;
                    };
                    if (found && str(this.charAt(i + j)) != str(oldStr.charAt(j))) {
                        found = false;
                    };
                    j = j + 1;
                };
                if (found) {
                    result = result + newStr;
                    i = i + oldLen;
                    replaced = replaced + 1;
                };
                if (!found) {
                    result = result + str(this.charAt(i));
                    i = i + 1;
                };
            };
            if (replaced >= occur) {
                result = result + str(this.charAt(i));
                i = i + 1;
            };
        };
        return result;
    };

    function replaceAll(oldStr: str, newStr: str) -> str {
        var result: str = "";
        var i: int = 0;
        var tLen: int = this.length;
        var oldLen: int = oldStr.length;
        while (i < tLen) {
            var j: int = 0;
            var found: bool = true;
            while (j < oldLen) {
                if (i + j >= tLen) {
                    found = false;
                };
                if (found && str(this.charAt(i + j)) != str(oldStr.charAt(j))) {
                    found = false;
                };
                j = j + 1;
            };
            if (found) {
                result = result + newStr;
                i = i + oldLen;
            };
            if (!found) {
                result = result + str(this.charAt(i));
                i = i + 1;
            };
        };
        return result;
    };

    function toUpper() -> str {
        return mocha_str_toupper_ffi(this);
    };

    function toLower() -> str {
        return mocha_str_tolower_ffi(this);
    };

    function split(delim: str) -> str[] {
        var result: str[] = [];
        var current: str = "";
        var i: int = 0;
        var tLen: int = this.length;
        var dLen: int = delim.length;
        while (i < tLen) {
            var j: int = 0;
            var found: bool = true;
            while (j < dLen) {
                if (i + j >= tLen) {
                    found = false;
                };
                if (found && str(this.charAt(i + j)) != str(delim.charAt(j))) {
                    found = false;
                };
                j = j + 1;
            };
            if (found) {
                result.push(current);
                current = "";
                i = i + dLen;
            };
            if (!found) {
                current = current + str(this.charAt(i));
                i = i + 1;
            };
        };
        result.push(current);
        return result;
    };

    function repeat(n: int) -> str {
        if (n <= 0) { return ""; };
        var result: str = "";
        var i: int = 0;
        while (i < n) {
            result = result + this;
            i++;
        };
        return result;
    };

    function padLeft(width: int, fill: str) -> str {
        if (this.length >= width) { return this; };
        var pad: str = fill.repeat(width - this.length);
        return pad + this;
    };

    function padRight(width: int, fill: str) -> str {
        if (this.length >= width) { return this; };
        var pad: str = fill.repeat(width - this.length);
        return this + pad;
    };

    function isAlpha() -> bool {
        if (this.length == 0) { return false; };
        var i: int = 0;
        while (i < this.length) {
            if (c_isalpha(str(this.charAt(i))) == 0) { return false; };
            i++;
        };
        return true;
    };

    function isNumeric() -> bool {
        if (this.length == 0) { return false; };
        var i: int = 0;
        while (i < this.length) {
            if (c_isdigit(str(this.charAt(i))) == 0) { return false; };
            i++;
        };
        return true;
    };

    function isAlphaNumeric() -> bool {
        if (this.length == 0) { return false; };
        var i: int = 0;
        while (i < this.length) {
            var ch: str = str(this.charAt(i));
            if (c_isalpha(ch) == 0 && c_isdigit(ch) == 0) { return false; };
            i++;
        };
        return true;
    };
    // does pattern match anywhere in string?
    function regex_match(pat: str) -> bool {
        var span: int[] = regex_find_span(pat, this);
        return span[0] != -1;
    };

    // does pattern match the entire string?
    function regex_full(pat: str) -> bool {
        var anchored: str = "^" + pat + "$";
        var span: int[] = regex_find_span(anchored, this);
        return span[0] != -1;
    };

    // return first match as str, "" if none
    function regex_find(pat: str) -> str {
        var span: int[] = regex_find_span(pat, this);
        if (span[0] == -1) { return ""; };
        return this.substring(span[0], span[1] - 1);
    };

    // return all non-overlapping matches
    function regex_find_all(pat: str) -> str[] {
        var results: str[] = [];
        var tlen: int = this.length;
        var i: int = 0;
        while (i <= tlen) {
            var end: int = regex_match_at(pat, this, i);
            if (end != -1 && end > i) {
                results.push(this.substring(i, end - 1));
                i = end;
            } else {
                i++;
            };
        };
        return results;
    };

    // replace all matches with replacement string
    function regex_replace_all(pat: str, replacement: str) -> str {
        var result: str = "";
        var tlen: int = this.length;
        var i: int = 0;
        while (i <= tlen) {
            var end: int = regex_match_at(pat, this, i);
            if (end != -1 && end > i) {
                result = result + replacement;
                i = end;
            } else {
                if (i < tlen) {
                    result = result + str(this.charAt(i));
                };
                i++;
            };
        };
        return result;
    };

    // split on pattern
    function regex_split(pat: str) -> str[] {
        var results: str[] = [];
        var tlen: int = this.length;
        var i: int = 0;
        var current: str = "";
        while (i <= tlen) {
            var end: int = regex_match_at(pat, this, i);
            if (end != -1 && end > i) {
                results.push(current);
                current = "";
                i = end;
            } else {
                if (i < tlen) {
                    current = current + str(this.charAt(i));
                };
                i++;
            };
        };
        results.push(current);
        return results;
    };
};
extend str[] {
    function join(delim: str) -> str {
        if (this.length == 0) { return ""; };
        var result: str = this[0];
        var i: int = 1;
        while (i < this.length) {
            result = result + delim + this[i];
            i++;
        };
        return result;
    };
};
// =============================================
// REGEX ENGINE — Tier 1
// Supports: . * + ? ^ $ [abc] [a-z] [^abc]
//           \d \w \s \D \W \S
// =============================================

// ── char class helpers ──

function regex_is_digit(c: str) -> bool {
    return c_isdigit(c) != 0;
};

function regex_is_word(c: str) -> bool {
    return c_isalpha(c) != 0 || c_isdigit(c) != 0 || c == "_";
};

function regex_is_space(c: str) -> bool {
    return c == " " || c == "\t" || c == "\n" || c == "\r";
};

// ── match a single pattern token against a single char ──
// returns true if char c matches pattern at position pi
// advances pi_out to next pattern position

function regex_match_char(pat: str, pi: int, c: str) -> bool {
    var plen: int = pat.length;
    if (pi >= plen) { return false; };
    var p: str = str(pat.charAt(pi));

    // escape sequences
    if (p == "\\" && pi + 1 < plen) {
        var next: str = str(pat.charAt(pi + 1));
        if (next == "d") { return regex_is_digit(c); };
        if (next == "D") { return !regex_is_digit(c); };
        if (next == "w") { return regex_is_word(c); };
        if (next == "W") { return !regex_is_word(c); };
        if (next == "s") { return regex_is_space(c); };
        if (next == "S") { return !regex_is_space(c); };
        return next == c;  // escaped literal
    };

    // dot — matches any char
    if (p == ".") { return true; };

    // character class [...]
    if (p == "[") {
        var ci: int = pi + 1;
        var negated: bool = false;
        if (ci < plen && str(pat.charAt(ci)) == "^") {
            negated = true;
            ci++;
        };
        var matched: bool = false;
        while (ci < plen && str(pat.charAt(ci)) != "]") {
            var cc: str = str(pat.charAt(ci));
            // range like a-z
            if (ci + 2 < plen && str(pat.charAt(ci + 1)) == "-" && str(pat.charAt(ci + 2)) != "]") {
                var lo: str = cc;
                var hi: str = str(pat.charAt(ci + 2));
                if (c >= lo && c <= hi) { matched = true; };
                ci = ci + 3;
            } else {
                if (cc == c) { matched = true; };
                ci++;
            };
        };
        if (negated) { return !matched; };
        return matched;
    };

    // literal match
    return p == c;
};

// ── how many pattern chars does one token consume? ──
function regex_token_len(pat: str, pi: int) -> int {
    var plen: int = pat.length;
    if (pi >= plen) { return 0; };
    var p: str = str(pat.charAt(pi));
    if (p == "\\" && pi + 1 < plen) { return 2; };
    if (p == "[") {
        var ci: int = pi + 1;
        if (ci < plen && str(pat.charAt(ci)) == "^") { ci++; };
        while (ci < plen && str(pat.charAt(ci)) != "]") {
            if (str(pat.charAt(ci)) == "-" && ci + 1 < plen && str(pat.charAt(ci + 1)) != "]") {
                ci = ci + 2;
            } else {
                ci++;
            };
        };
        return ci - pi + 1;
    };
    return 1;
};
// ── core recursive matcher ──
// returns length of match from ti, or -1 if no match
function regex_match_here(pat: str, text: str, pi: int, ti: int) -> int {
    var plen: int = pat.length;
    var tlen: int = text.length;

    // end of pattern — match succeeded
    if (pi >= plen) { return ti; };

    var p: str = str(pat.charAt(pi));

    // anchor $
    if (p == "$" && pi + 1 == plen) {
        if (ti == tlen) { return ti; };
        return -1;
    };

    var tok_len: int = regex_token_len(pat, pi);
    var next_pi: int = pi + tok_len;

    // check for quantifier after token
    var quantifier: str = "";
    if (next_pi < plen) {
        var q: str = str(pat.charAt(next_pi));
        if (q == "*" || q == "+" || q == "?") {
            quantifier = q;
        };
    };

    // ── * — zero or more (greedy) ──
    if (quantifier == "*") {
        // first consume as many chars as possible
        var max_i: int = ti;
        while (max_i < tlen && regex_match_char(pat, pi, str(text.charAt(max_i)))) {
            max_i++;
        };
        // try from longest match down to zero
        var i: int = max_i;
        while (i >= ti) {
            var result: int = regex_match_here(pat, text, next_pi + 1, i);
            if (result != -1) { return result; };
            i--;
        };
        return -1;
    };

    // ── + — one or more (greedy) ──
    if (quantifier == "+") {
        if (ti >= tlen || !regex_match_char(pat, pi, str(text.charAt(ti)))) {
            return -1;
        };
        // consume as many chars as possible
        var max_i2: int = ti + 1;
        while (max_i2 < tlen && regex_match_char(pat, pi, str(text.charAt(max_i2)))) {
            max_i2++;
        };
        // try from longest match down to one
        var i2: int = max_i2;
        while (i2 >= ti + 1) {
            var result2: int = regex_match_here(pat, text, next_pi + 1, i2);
            if (result2 != -1) { return result2; };
            i2--;
        };
        return -1;
    };

    // ── ? — zero or one ──
    if (quantifier == "?") {
        var result3: int = regex_match_here(pat, text, next_pi + 1, ti);
        if (result3 != -1) { return result3; };
        if (ti < tlen && regex_match_char(pat, pi, str(text.charAt(ti)))) {
            return regex_match_here(pat, text, next_pi + 1, ti + 1);
        };
        return -1;
    };

    // ── no quantifier — match exactly one ──
    if (ti >= tlen) { return -1; };
    if (!regex_match_char(pat, pi, str(text.charAt(ti)))) { return -1; };
    return regex_match_here(pat, text, next_pi, ti + 1);
};

// ── try match starting at position ti ──
// returns end position of match, or -1
function regex_match_at(pat: str, text: str, ti: int) -> int {
    var plen: int = pat.length;
    var p0: str = str(pat.charAt(0));

    // anchor ^ — only try at position 0
    if (plen > 0 && p0 == "^") {
        if (ti != 0) { return -1; };
        return regex_match_here(pat, text, 1, ti);
    };
    return regex_match_here(pat, text, 0, ti);
};

// ── find start and end of first match ──
// returns int[] of [start, end] or [-1, -1]
function regex_find_span(pat: str, text: str) -> int[] {
    var tlen: int = text.length;
    var plen: int = pat.length;
    var result: int[] = alloc int[2];
    result[0] = -1;
    result[1] = -1;

    // ^ anchored — only try at 0
    if (plen > 0 && str(pat.charAt(0)) == "^") {
        var end: int = regex_match_at(pat, text, 0);
        if (end != -1) {
            result[0] = 0;
            result[1] = end;
        };
        return result;
    };

    // $ anchored — match must end at tlen
    if (plen > 0 && str(pat.charAt(plen - 1)) == "$") {
        var i: int = 0;
        while (i <= tlen) {
            var end2: int = regex_match_at(pat, text, i);
            if (end2 != -1 && end2 == tlen) {
                result[0] = i;
                result[1] = end2;
                return result;
            };
            i++;
        };
        return result;
    };

    // unanchored — return first match
    var i: int = 0;
    while (i <= tlen) {
        var end2: int = regex_match_at(pat, text, i);
        if (end2 != -1) {
            result[0] = i;
            result[1] = end2;
            return result;
        };
        i++;
    };
    return result;
};