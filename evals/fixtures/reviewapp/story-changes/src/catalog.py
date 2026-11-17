"""A minimal in-memory catalog."""

from pagination import page_count

PER_PAGE = 10


class Catalog:
    def __init__(self, items):
        self.items = list(items)

    def __len__(self):
        return len(self.items)

    def page_count(self):
        return page_count(len(self.items), PER_PAGE)

    def page(self, n):
        start = (n - 1) * PER_PAGE
        return self.items[start:start + PER_PAGE]
