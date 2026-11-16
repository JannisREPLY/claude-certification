# Cert Trainer

Interactive, gamified learning app for certification exams.

## Run

```bash
cd app
docker compose up -d --build
```

Open http://localhost:8080 and pick a certification. Without Docker: `npm install && npm run dev` (no labs).

The stack has three services and only listens on `127.0.0.1`:

| Service | What |
|---|---|
| `cert-trainer` | nginx: the app, plus a proxy for `/code/` (editor) and `/api/lab/` (grader) |
| `lab` | code-server with Terraform 1.6.6, AWS CLI v2, and the grader API (`lab/grader.py`) |
| `moto` | Emulated AWS account; the `lab` container points `AWS_ENDPOINT_URL` at it |

AWS state lives in memory: after a restart of the stack, restart the lab.

## Phone

`.github/workflows/app-pages.yml` deploys a static build without labs (`VITE_NO_LABS=true npm run build`) to GitHub Pages on every push to `main` that touches `app/`. Open it on the phone and use "Add to Home Screen" to run it as an app.

Sync: `.env` points at the Supabase project; the dashboard shows a Sync card (Google sign-in). Progress is stored per certification in `cert_progress` (`supabase/migrations/`), which only the owner account can read or write. The newest progress wins as a whole; it is pulled on sign-in and when the app comes back to the foreground, and pushed 1 s after each change. The first device that signs in with progress becomes the source. Without `.env` progress stays local; move it with Export/Import.

Progress is stored in the browser's localStorage per certification; use **Export/Import** on the dashboard to back it up. The browser keeps progress per host and port, so `localhost:8080` and `localhost:5173` have separate progress.

## Add a certification

Create `src/certs/<cert-id>/content.json`. It is picked up automatically; with more than one certification a switcher appears in the header.

```jsonc
{
  "id": "my-cert",                       // unique, used as storage key
  "title": "My Certification",
  "exam": { "items": 60, "minutes": 120, "scenariosPerExam": 4, "passScore": 720, "minScore": 100, "maxScore": 1000 },
  "domains": [
    { "id": "d1", "name": "Domain name", "weight": 0.27,
      "taskStatements": [{ "id": "1.1", "title": "...", "knowledge": ["..."], "skills": ["..."] }] }
  ],
  "scenarios": [
    { "id": "scenario-id", "name": "Scenario name", "description": "...", "officialBank": true }
  ],
  "lessons": [
    { "id": "ch1", "title": "1. Lesson", "domain": "d1", "kind": "theory", "markdown": "..." }
  ],
  "questions": [
    { "id": "q1", "scenario": "scenario-id", "domain": "d1", "task": "1.1",
      "situation": "...", "question": "...",
      "options": [{ "text": "...", "correct": true }, { "text": "...", "correct": false }],
      "explanation": "...", "source": "guide",
      "hint": { "lesson": "ch1", "heading": "1.3 The `stop_reason` Field in the Response" } }
  ]
}
```

- `lessons[].kind`: `overview`, `theory`, `domain-notes` or `reference` (controls grouping on the Learn tab).
- `questions[].options`: more than one `correct` makes it a multiple-response item.
- `questions[].hint`: lesson and exact `##`/`###` heading text (or `null` for the whole lesson) opened by the hint button. A correct answer after a hint gives half XP and doesn't advance the card.
- `questions[].source`: `ai-draft` shows an “AI-drafted” label.
- Lesson check: a lesson ends with up to 5 questions whose `hint.lesson` is that lesson (`domain-notes` lessons use every question of their domain). Wrong answers come back until all are correct; only then is the lesson studied and "Next" unlocked. Lessons without such questions keep the plain "Mark as studied" button.
- Mock exams draw `scenariosPerExam` scenarios from those with `officialBank: true` and at least `items / scenariosPerExam` questions.

## Add a lab

Create `lab/labs/<lab-id>/`:

- `lab.json`: `id`, `cert` (certification id), `title`, `objectives`, `domain`, `minutes`, `intro` and `tasks` (`id`, `text`, both Markdown)
- `files/`: copied into the empty lab folder `/home/coder/lab`
- `setup.sh`: runs in the lab folder after the AWS account is reset (e.g. `terraform apply`, create resources by hand, cause drift)
- `checks/<task-id>.sh`: exit code 0 = task passed; the output is shown to the learner. `source "$LIB"` for helpers (`require_init`, `state_attr`, `expect_no_changes`, `plan_json`, …)

Rebuild with `docker compose up -d --build`. The app reads `lab.json` at build time, the grader at runtime.

Add `lab/solutions/<lab-id>.sh` (not copied into the image) and run `lab/test-labs.sh [lab-id]`: it starts each lab, expects every task to fail, runs the solution and expects every task to pass. S3 buckets that Terraform addresses need a network alias `<bucket>.moto` on the `moto` service in `compose.yaml`.

## How readiness works

- Each question is a spaced-repetition card (boxes 0–5, intervals 1/3/7/14/30 days). A correct answer only moves it up when the card is due; a wrong answer resets it.
- Domain mastery = average card mastery (box 4 = 100%). Readiness % = domain mastery weighted like the exam; the pass line is the pass mark converted to a percentage (720 on 100–1000 → 69%).
- Lab tasks count towards their lab's domain: a task passed once counts as mastered.
- **Exam ready** = readiness ≥ pass line, every domain ≥ 60%, all lessons studied, the latest mock exam passed, and (if the certification has labs) every lab passed in one check.
