"""A minimal in-memory catalog."""

PER_PAGE = 10


class Catalog:
    def __init__(self, items):
        self.items = list(items)

    def __len__(self):
        return len(self.items)
