# AGENTS.md

## LLM-assisted contributions

FNF-LOVE-NeonCadence welcomes contributions made with large language models
(LLMs) and other AI assistants, provided a human contributor understands,
reviews, and takes responsibility for the changes. Using these tools is optional.

This policy applies to this fork. Contributions sent to the upstream project
must follow that project's own contribution rules.

## Human-authored comments and documentation

Code comments, docstrings, and repository documentation must be written by
human contributors. LLMs and other AI assistants must not create, expand, or
rewrite them. Reviewing or copying LLM-generated text does not satisfy this
authorship requirement.

Assistants may preserve or relocate existing comments and documentation when
refactoring the code they describe. Keep copyright notices and license terms
intact.

## Required human explanation

For every LLM-assisted contribution, the submitting human must provide an
explanation in their own words in the pull request description (or accompanying
commit message when contributing without a pull request). It must explain:

- What changed and what problem or goal the change addresses.
- How the change works, including the important decisions behind it.
- How the change was checked, what the results were, and any checks not performed.
- Any known limitations, risks, or tradeoffs.

The explanation must be written by the human contributor. An LLM-generated
summary, copied output, or a statement such as "the AI fixed it" does not satisfy
this requirement. The contributor must review the full diff and be able to
answer follow-up questions about the change. Maintainers must request
clarification and withhold acceptance when the explanation is missing or does
not demonstrate understanding.

## Guidance for AI assistants

- You may help with code, debugging, tests, and reviews. Do not author code
  comments, docstrings, or repository documentation.
- Explain your changes in conversation and report validation results accurately;
  do not claim that unperformed checks passed. Conversational explanations do
  not replace human-authored comments, documentation, or contribution explanations.
- Remind the user to review the diff and supply the required human explanation
  before submitting a contribution. Do not write that explanation on their
  behalf or claim that the user understands changes they have not explained.
- Follow the repository's coding conventions and retain applicable copyright
  notices and license terms. This contribution policy does not change them.
