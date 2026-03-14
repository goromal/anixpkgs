# workout-planner

AI-powered workout planner with Google Tasks integration.

Generates personalized daily workout plans using Claude API and publishes
them as Google Tasks. Tracks workout history and completion status.

[Repository](https://github.com/goromal/workout-planner)

### Architecture

1. **workout-planner** Python package - AI-powered workout generation
2. **ATS integration** - Automated daily job at 05:30
3. **Configuration system** - User-editable YAML config
4. **History tracking** - JSONL-based workout log

### Data Flow

```
05:30 Daily Trigger
    ↓
ats-workout-planner job
    ↓
├─ authm refresh (Google Auth)
├─ rcrsync sync configs (Sync config file)
├─ workout-planner generate
│   ├─ Check for carryover workouts (incomplete tasks)
│   ├─ SKIP if carryover exists → Exit
│   ├─ Load ~/configs/workout-config.yaml
│   ├─ Load recent history from ~/data/workout/history.jsonl
│   ├─ Count workouts completed this week
│   ├─ SKIP if weekly target reached → Exit
│   ├─ Call Claude API for workout generation (ONLY if needed)
│   ├─ Create Google Task "P0: Workout: ..."
│   └─ Append to history log
└─ logger success message

06:00 ats-task-migrator
    └─ Migrates incomplete tasks (including missed workouts)
```

### Configuration

**Location**: `~/configs/workout-config.yaml`

**Structure**:

```yaml
goals:
  - Your fitness goals
constraints:
  - Session length, equipment, injuries
available_equipment:
  - List of equipment
preferences:
  split: push_pull_legs
  frequency_per_week: 4
  style: mixed
api:
  model: (see https://platform.claude.com/docs/en/about-claude/models/overview)
current_status:
  last_updated: "YYYY-MM-DD"
  notes: "Current focus areas"
```

## Usage

```bash
Usage: workout-planner [OPTIONS] COMMAND [ARGS]...

  AI-powered workout planner with Google Tasks integration.

Options:
  --config-file PATH          Path to workout configuration YAML file.
                              [default: /homeless-shelter/configs/workout-
                              config.yaml]
  --history-file PATH         Path to workout history JSONL file.  [default:
                              /homeless-shelter/data/workout/history.jsonl]
  --claude-api-key-file PATH  Path to Claude API key file.  [default:
                              /homeless-shelter/secrets/claude/api_key.txt]
  --task-secrets-file PATH    Google Tasks client secrets file.  [default:
                              /homeless-
                              shelter/secrets/google/client_secrets.json]
  --task-refresh-token PATH   Google Tasks refresh token file.  [default:
                              /homeless-shelter/secrets/google/refresh.json]
  --task-list-id TEXT         UUID of the Google Task List.  [default:
                              MDY2MzkyMzI4NTQ1MTA0NDUwODY6MDow]
  --enable-logging            Enable verbose logging.
  --help                      Show this message and exit.

Commands:
  check-yesterday  Check if yesterday's workout was completed.
  generate         Generate today's workout plan and create a Google Task.
  history          Display recent workout history.
```

### generate


```bash
Usage: workout-planner generate [OPTIONS]

  Generate today's workout plan and create a Google Task.

  This command: 1. Checks for carryover workouts (incomplete tasks from
  previous days) 2. Checks if weekly workout target has been reached 3. If
  needed, generates a personalized workout using Claude API 4. Creates a
  Google Task with the workout 5. Logs the workout to history

  No workout is generated if: - There's a carryover workout (incomplete task
  exists) - Weekly workout target has been reached

Options:
  --dry-run                       Generate workout but don't create task or
                                  log to history.
  --force-yesterday-completed BOOLEAN
                                  Override yesterday's completion status
                                  (True/False).
  --help                          Show this message and exit.
```

### history


```bash
Usage: workout-planner history [OPTIONS]

  Display recent workout history.

Options:
  --days INTEGER  Number of days of history to display.  [default: 7]
  --help          Show this message and exit.
```

### check-yesterday


```bash
Usage: workout-planner check-yesterday [OPTIONS]

  Check if yesterday's workout was completed.

Options:
  --help  Show this message and exit.
```

