# CollegeSapien CTF — operator guide

A seven-challenge capture-the-flag hidden in our own API, run as a talent
funnel. The point is not security theatre: it is to find students who poke at
things, and to end up holding a ranked list of them with contact details.

## Why it is built the way it is

**This repository is public**, so a hardcoded flag would be findable with one
`git grep` and worth nothing as a signal. Every flag is derived at runtime by
HMAC from `CTF_FLAG_SECRET`, which exists only in the function environment.
There is no answer key in the source tree — including in this file.

**Flags from `ch04` onward are minted per solver** and carry an 8-hex
fingerprint of the solver's UID. Two consequences:

- A flag pasted into a WhatsApp group still points at whoever earned it. The
  submit endpoint answers `403 "That flag was issued to somebody else"` rather
  than a plain wrong-answer, and records `borrowedFlagAttempts` on the
  borrower.
- On `ch06` the proof-of-work seed is derived per user, so copying an answer
  is not dishonourable, it is simply useless. Everyone has a different puzzle.

**It runs as its own Cloud Function** (`ctf`, `maxInstances: 3`) rather than
inside `api`. It is the one service we actively invite people to hammer, and
its instance budget is deliberately separate so a busy challenge night cannot
slow down the app students rely on for attendance.

## The challenges

| id | name | tests | points | login |
|------|---------------|-------------------------------------|-------:|-------|
| ch01 | handshake | a response is more than its body | 10 | no |
| ch02 | layers | recognising and peeling encodings | 20 | no |
| ch03 | preconditions | HTTP conditional requests | 30 | no |
| ch04 | token | what is inside an auth token | 50 | yes |
| ch05 | relay | driving an API from code | 80 | yes |
| ch06 | grind | **writing real code** | 150 | yes |
| ch07 | finale | finishing what you started | 200 | yes |

`ch06` is the one that matters. It cannot be done by hand, it is verified in
constant time, and the per-user seed makes it uncopyable. If you only look at
one column when shortlisting, look at who solved `ch06`.

The first three need no account so a prospective student — or someone who is
not ours yet — can start immediately. The rest need a verified college login,
which is what turns a solve into a name you can email.

## Setup

1. Generate a secret and put it in `server/functions/.env` (gitignored):

   ```
   openssl rand -hex 32
   ```

   ```
   CTF_FLAG_SECRET=<the value>
   ```

2. Deploy:

   ```
   cd server && firebase deploy --only functions:ctf
   ```

3. Deploy hosting so `robots.txt`, `security.txt` and `/ctf.html` go live.

Without `CTF_FLAG_SECRET` the CTF serves `503` in production rather than
running on a guessable secret. Rotating the secret invalidates every
previously issued flag, so rotate between seasons, not mid-season.

## How players find it

Three breadcrumbs, in increasing order of obviousness:

- `X-Codesapiens-Challenge` header on **every** production API response.
  Anyone who has opened a Network tab trips over it.
- `robots.txt` on the marketing site.
- `/.well-known/security.txt`, which also carries the real disclosure address.

`security.txt` deliberately separates the two: planted flags go to the
scoreboard, real findings go to the mailbox, and real findings are worth more.

## Scope, and why it is written down

The full scope statement ships in the briefing response and on `/ctf.html`.
The difference between a CTF player and an incident is usually just that
nobody wrote this down. In scope: the CTF service, the marketing site, the
public repo. Out of scope: production data, other students' accounts, denial
of service, social engineering.

If a player finds something we did not plant, they are told to stop, not
exploit it, and mail `security@collegesapien.com`.

## Data and privacy

`ctf_progress/{uid}` holds solved challenges, timestamps, points, the opt-in
handle and the email. Firestore rules allow a player to read **only their own**
record and allow no client writes at all — scores are written by the CTF
function through the Admin SDK, which bypasses rules. A client that could
write here could award itself every flag.

The leaderboard is opt-in, served by the API rather than by direct reads, and
exposes only the chosen handle — never an email or UID. Players can ask for
their CTF record to be erased.

## Verifying a deploy

Reference solutions, so anyone on the team can confirm the CTF still works
after a change. `$CTF` is the function base URL.

```bash
# ch01 — the flag is in a header
curl -si "$CTF/" | grep -i x-ctf-ch01-flag

# ch02 — base64( rot13( base64( flag ) ) )
curl -s "$CTF/ch02" | jq -r .payload \
  | base64 -d | tr 'A-Za-z' 'N-ZA-Mn-za-m' | base64 -d

# ch03 — conditional request
ETAG=$(curl -si "$CTF/ch03" | awk '/[Ee][Tt]ag:/{print $2}' | tr -d '\r')
curl -s -H "If-Match: $ETAG" "$CTF/ch03" | jq -r .flag
```

`ch04`–`ch07` need a Firebase ID token (`-H "Authorization: Bearer $TOKEN"`).
`ch05` is a loop following `X-Next-Hop` for 50 hops; `ch06` is a loop over
`sha256(seed + nonce)` until the digest has five leading zeros — about a
million hashes, under a second in most languages.

## Running the numbers on cost

Every endpoint except `submit`, `progress`, `ch07` and the leaderboard is
pure computation with no database access, so the common path is a function
invocation and nothing else. Flag submission is rate limited (60 per 15 min)
because each wrong guess is a Firestore read; proof-of-work verification gets
a looser limit (120) since solvers legitimately retry and it touches no
database.
