# AGENTS.md

The iOS version of Puzzles. Not started yet, so there is no code here. Stack, commands and structure belong here once it starts.

## Rules

- MUST have the same eight games as puzzles-android and puzzles-web, and behave the same: Sudoku (classic and killer), Klondike Solitaire, Two Tone, Sightlines, Five Letters, Kakuro, Slide Out and Word Wheel.
- MUST download puzzle banks from https://joclegg.github.io/puzzles-data/ and keep them on the device, so every game plays offline once they have downloaded.
- MUST NOT bundle puzzle banks in the app or the repository.
- MUST NOT add analytics or ads.
- MUST keep sign-in optional, so every game plays signed out.
- MUST NOT commit secrets. This repository's settings and Actions secrets are managed in joclegg-infra.
