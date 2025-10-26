"""A simple calculator module for basic arithmetic operations."""


def add(a, b):
    """Add two numbers.

    Args:
        a: First number
        b: Second number

    Returns:
        The sum of a and b
    """
    return a + b


def subtract(a, b):
    """Subtract b from a.
    
    This function contains a pre-existing (ignored) linting error
    to simulate legacy code that we're not fixing yet.

    Args:
        a: First number
        b: Second number

    Returns:
        The difference of a and b
    """
    # This unused variable simulates legacy technical debt
    # Ignored via per-file-ignores in .flake8
    unused_variable = 123  # noqa: F841
    return a - b


def multiply(a, b):
    """Multiply two numbers.

    Args:
        a: First number
        b: Second number

    Returns:
        The product of a and b
    """
    return a * b


def divide(a, b):
    """Divide a by b.

    Args:
        a: First number (dividend)
        b: Second number (divisor)

    Returns:
        The quotient of a and b

    Raises:
        ValueError: If b is zero
    """
    if b == 0:
        raise ValueError("Cannot divide by zero")
    return a / b