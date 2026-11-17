"""Pure page arithmetic."""


def page_count(total, per_page):
    """Number of pages needed to show `total` items, `per_page` at a time."""
    return total // per_page
