#!/usr/bin/env python3
"""A side-effect-free launcher calculator for explicit `=expression` queries.

Whitelist AST nodes and math functions only: no Python eval(), filesystem,
commands, dynamic imports, attribute access or comprehensions.
"""
import argparse
import ast
import json
import math
import operator

FUNCTIONS = {'sqrt': math.sqrt, 'sin': math.sin, 'cos': math.cos,
             'tan': math.tan, 'ln': math.log, 'log10': math.log10,
             'abs': abs, 'floor': math.floor, 'ceil': math.ceil, 'round': round}
CONSTANTS = {'pi': math.pi, 'e': math.e, 'tau': math.tau}
BINARY = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
          ast.Div: operator.truediv, ast.Mod: operator.mod,
          ast.Pow: operator.pow}
UNARY = {ast.UAdd: operator.pos, ast.USub: operator.neg}


# Compact dimensional conversion, with explicit compatible-unit families only.
# No exchange rates, no network, and no arbitrary string evaluation.
import re
CONVERSIONS = {
    'length': {'mm': .001, 'cm': .01, 'm': 1, 'km': 1000, 'in': .0254, 'ft': .3048, 'yd': .9144, 'mi': 1609.344},
    'mass': {'mg': .001, 'g': 1, 'kg': 1000, 'oz': 28.349523125, 'lb': 453.59237},
    'volume': {'ml': .001, 'l': 1, 'cup': .2365882365, 'pt': .473176473, 'gal': 3.785411784},
    'duration': {'ms': .001, 's': 1, 'min': 60, 'hr': 3600, 'day': 86400},
}
TEMP = {'c','f','k'}
CONVERT_PATTERN = re.compile(r'^\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+))\s*([A-Za-z°]+)\s+to\s+([A-Za-z°]+)\s*$', re.I)


def convert(expression):
    matched = CONVERT_PATTERN.fullmatch(expression)
    if not matched:
        return None
    quantity = float(matched.group(1))
    if not math.isfinite(quantity) or abs(quantity) > 1e11:
        raise ValueError('Quantity outside safe limits')
    first, second = matched.group(2).lower().replace('°',''), matched.group(3).lower().replace('°','')
    if first in TEMP or second in TEMP:
        if first not in TEMP or second not in TEMP:
            raise ValueError('Incompatible conversion dimensions')
        kelvin = quantity + 273.15 if first == 'c' else (quantity + 459.67) * (5/9) if first == 'f' else quantity
        if kelvin < 0:
            raise ValueError('Temperature below absolute zero')
        answer = kelvin - 273.15 if second == 'c' else kelvin * (9/5) - 459.67 if second == 'f' else kelvin
    else:
        group = next((units for units in CONVERSIONS.values() if first in units and second in units), None)
        if group is None:
            raise ValueError('Unknown or incompatible units')
        answer = quantity * group[first] / group[second]
    if not math.isfinite(answer) or abs(answer) > 1e14:
        raise ValueError('Conversion outside safe limits')
    formatted = str(int(round(answer))) if abs(answer-round(answer)) < 1e-10 else format(answer, '.12g')
    return formatted + ' ' + second


def evaluate(source):
    if not isinstance(source, str) or not 1 <= len(source) <= 160:
        raise ValueError('Expression must be 1–160 characters')
    converted = convert(source)
    if converted is not None:
        return converted
    tree = ast.parse(source.replace('^', '**'), mode='eval')
    if sum(1 for _ in ast.walk(tree)) > 70:
        raise ValueError('Expression is too complex')
    def visit(node, depth=0):
        if depth > 18:
            raise ValueError('Nested expression limit exceeded')
        if isinstance(node, ast.Expression):
            return visit(node.body, depth + 1)
        if isinstance(node, ast.Constant) and type(node.value) in (int, float):
            value = float(node.value)
            if not math.isfinite(value) or abs(value) > 1e14:
                raise ValueError('Number outside safe limits')
            return value
        if isinstance(node, ast.Name) and node.id in CONSTANTS:
            return CONSTANTS[node.id]
        if isinstance(node, ast.UnaryOp) and type(node.op) in UNARY:
            return UNARY[type(node.op)](visit(node.operand, depth + 1))
        if isinstance(node, ast.BinOp) and type(node.op) in BINARY:
            left, right = visit(node.left, depth+1), visit(node.right, depth+1)
            if type(node.op) is ast.Pow and (abs(right) > 12 or abs(left) > 1e6):
                raise ValueError('Exponent too large')
            if type(node.op) is ast.Mod and right == 0:
                raise ValueError('Cannot mod by zero')
            return BINARY[type(node.op)](left, right)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and \
                node.func.id in FUNCTIONS and len(node.args) == 1 and not node.keywords:
            return FUNCTIONS[node.func.id](visit(node.args[0], depth+1))
        raise ValueError('Unsupported mathematical expression')
    try:
        value = float(visit(tree))
    except (OverflowError, ZeroDivisionError, SyntaxError, TypeError) as exc:
        raise ValueError('Invalid arithmetic operation') from exc
    if not math.isfinite(value) or abs(value) > 1e14:
        raise ValueError('Result outside safe limits')
    if value.is_integer():
        return str(int(value))
    return format(value, '.12g')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('expression')
    args = parser.parse_args()
    try:
        print(json.dumps({'ok': True, 'expression': args.expression,
                          'result': evaluate(args.expression)}))
    except (ValueError, SyntaxError) as exc:
        print(json.dumps({'ok': False, 'expression': args.expression, 'error': str(exc)}))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
