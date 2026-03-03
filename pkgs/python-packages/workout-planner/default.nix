{
  buildPythonPackage,
  setuptools,
  pytestCheckHook,
  click,
  pyyaml,
  anthropic,
  easy-google-auth,
  pkg-src,
}:
buildPythonPackage rec {
  pname = "workout-planner";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = pkg-src;
  propagatedBuildInputs = [
    click
    pyyaml
    anthropic
    easy-google-auth
  ];
  doCheck = false; # No tests yet
  meta = {
    description = "AI-powered workout planner with Google Tasks integration.";
    longDescription = ''
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
    '';
    autoGenUsageCmd = "--help";
    subCmds = [
      "generate"
      "history"
      "check-yesterday"
    ];
  };
}
