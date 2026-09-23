import random


class Queue:
    def __init__(self):
        self.tracks = []
        self.index = -1
        self.shuffle = False
        self.repeat = 'none'
        self.history = []
        self.remaining = []

    @property
    def current(self):
        return self.tracks[self.index] if 0 <= self.index < len(self.tracks) else {}

    def replace(self, tracks, index=0):
        if not tracks or not 0 <= index < len(tracks):
            raise ValueError('This album has no playable tracks.')
        self.tracks = list(tracks)
        self.index = index
        self.history = []
        self.set_shuffle(self.shuffle)

    def append(self, tracks):
        start = len(self.tracks)
        self.tracks.extend(tracks)
        self.remaining.extend(range(start, len(self.tracks)))
        if self.shuffle:
            random.shuffle(self.remaining)

    def select(self, index):
        if not 0 <= index < len(self.tracks):
            raise ValueError('Track is no longer in the queue.')
        if self.index >= 0 and self.index != index:
            self.history.append(self.index)
        self.index = index
        if index in self.remaining:
            self.remaining.remove(index)
        return self.current

    def set_shuffle(self, enabled):
        self.shuffle = enabled
        self.remaining = [i for i in range(len(self.tracks)) if i != self.index]
        random.shuffle(self.remaining)

    def advance(self, automatic=False):
        if not self.tracks:
            return None
        if automatic and self.repeat == 'one':
            return self.current
        if self.shuffle:
            if not self.remaining:
                if self.repeat != 'all':
                    return None
                self.set_shuffle(True)
            return self.select(self.remaining[-1]) if self.remaining else self.current
        next_index = self.index + 1
        if next_index >= len(self.tracks):
            if self.repeat != 'all':
                return None
            next_index = 0
        return self.select(next_index)

    def previous(self):
        if not self.tracks:
            return None
        index = self.history.pop() if self.shuffle and self.history else max(0, self.index - 1)
        self.index = index
        return self.current

    def remove(self, index):
        if not 0 <= index < len(self.tracks):
            raise ValueError('Track is no longer in the queue.')
        current_removed = index == self.index
        self.tracks.pop(index)
        def adjusted(items):
            return [i - 1 if i > index else i for i in items if i != index]
        self.history = adjusted(self.history)
        self.remaining = adjusted(self.remaining)
        if not self.tracks:
            self.index = -1
        elif index < self.index:
            self.index -= 1
        elif current_removed:
            self.index = min(index, len(self.tracks) - 1)
            if self.index in self.remaining:
                self.remaining.remove(self.index)
        return current_removed
