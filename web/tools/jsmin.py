"""Strip comments (and leading indentation) from the app's JavaScript, CSS and HTML at build time.

The sources keep their comments; the built page does not need them, and some of them talk about things the learner
must not find in the page before the time comes. This is not a minifier: names and code stay exactly as written.

JavaScript is read with a small tokenizer that knows strings, template literals (with nested ${...}), regular
expression literals and comments, so text inside strings and templates is never touched. A comment that spans lines
becomes one newline, so automatic semicolon insertion sees the same line breaks as before.
"""
import re

_REGEX_BEFORE = set('(,=:[!&|?{};+-*%<>~^')
_REGEX_WORDS = {'return', 'typeof', 'case', 'do', 'else', 'in', 'of', 'new', 'delete', 'void', 'throw', 'instanceof',
                'yield', 'await'}


def strip_js(src):
    out = []
    i, n = 0, len(src)
    modes = [['code', 0]]  # code (brace depth) or tpl; ${ in a template pushes a code mode
    last = ''  # last significant character (or word) in code, to tell a regex from a division
    at_line_start = True
    while i < n:
        mode = modes[-1]
        c = src[i]
        if mode[0] == 'tpl':
            if c == '\\':
                out.append(src[i:i + 2])
                i += 2
            elif c == '`':
                out.append(c)
                i += 1
                modes.pop()
                last = 'a'
            elif c == '$' and src.startswith('${', i):
                out.append('${')
                i += 2
                modes.append(['code', 0])
                last = '{'
            else:
                out.append(c)
                i += 1
            continue
        # code
        if c == '\n':
            out.append('\n')
            i += 1
            while i < n and src[i] in ' \t':
                i += 1
            at_line_start = True
            continue
        if c in ' \t\r':
            if not at_line_start:
                out.append(c)
            i += 1
            continue
        at_line_start = False
        if c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == '\\':
                    j += 1
                elif src[j] == '\n':
                    raise ValueError(f'unterminated string at {i}: {src[i:i + 40]!r}')
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
            last = 'a'
            continue
        if c == '`':
            out.append(c)
            i += 1
            modes.append(['tpl', 0])
            continue
        if c == '/' and src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if c == '/' and src.startswith('/*', i):
            j = src.find('*/', i + 2)
            if j < 0:
                raise ValueError(f'unterminated comment at {i}')
            body = src[i:j + 2]
            i = j + 2
            if '\n' in body:
                out.append('\n')
                while i < n and src[i] in ' \t':
                    i += 1
                at_line_start = True
            elif out and out[-1] not in ' \n' and i < n and src[i] not in ' \n;,)':
                out.append(' ')
            continue
        if c == '/' and (last in _REGEX_BEFORE or last in _REGEX_WORDS or last == ''):
            j = i + 1
            cls = False
            while j < n:
                ch = src[j]
                if ch == '\\':
                    j += 2
                    continue
                if ch == '\n':
                    raise ValueError(f'unterminated regex at {i}: {src[i:i + 40]!r}')
                if cls:
                    if ch == ']':
                        cls = False
                elif ch == '[':
                    cls = True
                elif ch == '/':
                    break
                j += 1
            j += 1
            while j < n and (src[j].isalpha()):
                j += 1
            out.append(src[i:j])
            i = j
            last = 'a'
            continue
        if c.isalnum() or c in '_$':
            j = i
            while j < n and (src[j].isalnum() or src[j] in '_$'):
                j += 1
            word = src[i:j]
            out.append(word)
            i = j
            last = word if word in _REGEX_WORDS else 'a'
            continue
        if c == '{':
            mode[1] += 1
        elif c == '}':
            if mode[1] == 0 and len(modes) > 1:
                modes.pop()  # back into the template
                out.append(c)
                i += 1
                continue
            mode[1] -= 1
        out.append(c)
        i += 1
        last = c if c not in ')]' else 'a'
    if len(modes) != 1:
        raise ValueError('unbalanced template literal')
    text = ''.join(out)
    return re.sub(r'\n{2,}', '\n', text).strip() + '\n'


def strip_css(css):
    css = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
    css = re.sub(r'\n[ \t]+', '\n', css)
    return re.sub(r'\n{2,}', '\n', css)


def strip_html_comments(html):
    return re.sub(r'<!--.*?-->', '', html, flags=re.S)
