#!/usr/bin/env bash

# shellcheck source=/dev/null
source ./bin/generator-utils/utils.sh;
source ./bin/generator-utils/prompts.sh;

# Exit if anything fails.
set -euo pipefail

# If argument not provided, print usage and exit
if [ $# -ne 1 ]; then
    echo "Usage: bin/generate_practice_exercise.sh <exercise-slug>"
    exit 1
fi

# Check if sed is gnu-sed
if ! sed --version | grep -q "GNU sed"; then
    echo "GNU sed is required. Please install it and make sure it's in your PATH."
    exit 1
fi

# Check if jq and curl are installed
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but not installed. Aborting."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "curl is required but not installed. Aborting."; exit 1; }

# ==================================================


SLUG="$1"
UNDERSCORED_SLUG=$(dash_to_underscore "$SLUG")
EXERCISE_DIR="exercises/practice/${SLUG}"
AUTHOR_NAME=$(get_author_name)
message "info" "You entered: $AUTHOR_NAME. You can edit this later in .meta/config.json.authors"
EXERCISE_NAME=$(get_exercise_name "$SLUG")
message "info" "You entered: $EXERCISE_NAME. You can edit this later in config.json"
EXERCISE_DIFFICULTY=$(get_exercise_difficulty)
message "info" "EXERCISE_DIFFICULTY is set to $EXERCISE_DIFFICULTY. You can edit this later in config.json"


echo "Creating Rust files"
cargo new --lib "$EXERCISE_DIR" -q
mkdir -p "$EXERCISE_DIR"/tests
touch "${EXERCISE_DIR}/tests/${SLUG}.rs"

cat <<EOT > "${EXERCISE_DIR}/tests/${SLUG}.rs"
use ${UNDERSCORED_SLUG}::*
// Add tests here
EOT


cat <<EOT > "${EXERCISE_DIR}/src/lib.rs"
fn ${UNDERSCORED_SLUG}(){
    unimplemented!("implement ${SLUG} exercise")
}
EOT

cat <<EOT > "$EXERCISE_DIR"/.gitignore
# Generated by Cargo
# Will have compiled files and executables
/target/
**/*.rs.bk

# Remove Cargo.lock from gitignore if creating an executable, leave it for libraries
# More information here http://doc.crates.io/guide.html#cargotoml-vs-cargolock
Cargo.lock
EOT
message "success" "Created Rust files, tests dir and updated gitignore!"


mkdir "${EXERCISE_DIR}/.meta"
touch "${EXERCISE_DIR}/.meta/example.rs"
cat <<EOT > "${EXERCISE_DIR}/.meta/example.rs"
// Create a solution that passes all the tests
EOT
message "success" "Created example.rs file"


# ==================================================

# build configlet
./bin/fetch-configlet
message "success" "Fetched configlet successfully!"


# Preparing config.json
echo "Adding instructions and configuration files..."
UUID=$(bin/configlet uuid)

jq --arg slug "$SLUG" --arg uuid "$UUID" --arg name "$EXERCISE_NAME" --arg difficulty "$EXERCISE_DIFFICULTY" \
'.exercises.practice += [{slug: $slug, name: $name, uuid: $uuid, practices: [], prerequisites: [], difficulty: $difficulty}]' \
config.json > config.json.tmp
# jq always rounds whole numbers, but average_run_time needs to be a float
sed -i 's/"average_run_time": \([0-9]\+\)$/"average_run_time": \1.0/' config.json.tmp
mv config.json.tmp config.json
message "success" "Added instructions and configuration files"

# Create instructions and config files
echo "Creating instructions and config files"
./bin/configlet sync --update --yes --docs --metadata --exercise "$SLUG"
./bin/configlet sync --update --yes --filepaths --exercise "$SLUG"
./bin/configlet sync --update --tests include --exercise "$SLUG"
message "success" "Created instructions and config files"


sed -i "s/name = \".*\"/name = \"$UNDERSCORED_SLUG\"/" "$EXERCISE_DIR"/Cargo.toml

message "done" "All stub files were created."

message "info" "After implementing the solution, tests and configuration, please run:"
echo "./bin/configlet fmt --update --yes --exercise ${SLUG}"
