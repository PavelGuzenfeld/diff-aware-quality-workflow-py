"""Unit tests for calculator module."""

import pytest

from src.calculator import add, divide, multiply, subtract


class TestAdd:
    """Test cases for the add function."""

    def test_add_positive_numbers(self):
        """Test adding two positive numbers."""
        assert add(2, 3) == 5

    def test_add_negative_numbers(self):
        """Test adding two negative numbers."""
        assert add(-2, -3) == -5

    def test_add_mixed_numbers(self):
        """Test adding positive and negative numbers."""
        assert add(5, -3) == 2


class TestSubtract:
    """Test cases for the subtract function."""

    def test_subtract_positive_numbers(self):
        """Test subtracting two positive numbers."""
        assert subtract(5, 3) == 2

    def test_subtract_negative_numbers(self):
        """Test subtracting two negative numbers."""
        assert subtract(-5, -3) == -2

    def test_subtract_mixed_numbers(self):
        """Test subtracting positive and negative numbers."""
        assert subtract(5, -3) == 8


class TestMultiply:
    """Test cases for the multiply function."""

    def test_multiply_positive_numbers(self):
        """Test multiplying two positive numbers."""
        assert multiply(3, 4) == 12

    def test_multiply_negative_numbers(self):
        """Test multiplying two negative numbers."""
        assert multiply(-3, -4) == 12

    def test_multiply_mixed_numbers(self):
        """Test multiplying positive and negative numbers."""
        assert multiply(3, -4) == -12

    def test_multiply_by_zero(self):
        """Test multiplying by zero."""
        assert multiply(5, 0) == 0


class TestDivide:
    """Test cases for the divide function."""

    def test_divide_positive_numbers(self):
        """Test dividing two positive numbers."""
        assert divide(10, 2) == 5

    def test_divide_negative_numbers(self):
        """Test dividing two negative numbers."""
        assert divide(-10, -2) == 5

    def test_divide_mixed_numbers(self):
        """Test dividing positive and negative numbers."""
        assert divide(10, -2) == -5

    def test_divide_by_zero(self):
        """Test dividing by zero raises ValueError."""
        with pytest.raises(ValueError, match="Cannot divide by zero"):
            divide(10, 0)

    def test_divide_zero_by_number(self):
        """Test dividing zero by a number."""
        assert divide(0, 5) == 0
