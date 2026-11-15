# Writing style: ASD-STE100

Write all text in the style of ASD-STE100 Simplified Technical English (STE). Short, clear text is quicker to read and has only one meaning.

STE100 is a controlled language from the aerospace industry (ASD). Full STE also uses an approved dictionary of approximately 900 words. These rules do not include the dictionary. Use the writing rules only.

## Where to use it

- Issues and issue comments
- Pull requests and PR comments
- Commit messages
- Code comments
- Chat replies. Make them short.

## Rules

To use these rules for all text, copy them into your `~/.claude/CLAUDE.md`. If you change a rule here, change it there too.

- Use a maximum of 20 words in an instruction sentence.
- Use a maximum of 25 words in a description sentence.
- Write one instruction in each sentence.
- Use the imperative for instructions. Example: "Set the Status."
- Use the active voice.
- Use a maximum of 6 sentences in a paragraph.
- Use one word for one meaning. Do not use different words for the same thing.
- Use simple words. Example: write "make sure", not "verify" or "ensure".
- You can use technical names: code names, file names, `PR`, `workflow`.
- Write facts directly. If you are not sure, write that in a separate sentence. Example: "I did not test this on Windows."
- Put the most important information first.
- Use a list for 3 or more items.

## Limits

- Do not change all old code comments at one time. That makes large diffs with no change in function. Change a comment only when you edit that code.
- In repos that other people own, the style of that repo has priority.
- Do not change text that the owner wrote, for example the original text that `refine-issue` keeps.

## Examples

**Instruction**

> Before: Once you've made sure everything looks good, you'll probably want to go ahead and push the branch, and then a PR should be opened against main.
>
> After: Push the branch. Open a PR against `main`.

**Description**

> Before: The card is moved back to In Progress by a board automation that gets triggered whenever a pull request is linked to the issue.
>
> After: A board automation moves the card back to In Progress. The automation starts when a PR links to the issue.

**Uncertainty**

> Before: This should probably work on Windows too, but it might need some tweaks.
>
> After: This works on Linux. I did not test it on Windows.

**Commit message**

> Before: Fixed a bunch of stuff in the sweep script that was causing issues with archived items
>
> After: Skip archived items in the board sweep

**Code comment**

> Before: `# Here we're basically just looping through all of the items and checking whether each of them is missing a value`
>
> After: `# Find the items with an empty Status.`

**One word for one meaning**

> Before: Move the card to Review. When the ticket is in review, …
>
> After: Move the card to Review. When the card is in Review, …
