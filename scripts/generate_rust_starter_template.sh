#!/bin/bash
echo -e "\n\n###ALWAYS CHECK SCRIPTS FOR MALICIOUS CODE BEFORE EXECUTING THEM###\n\n"
# check if $0.sha256 exists
if [ -f "$0.sha256" ]; then
	checksum="$(cat $0.sha256 | awk -F ' ' '{print $1}')"
	echo "Checksum: $checksum"
	if ! echo "$checksum $0" | sha256sum -c - > /dev/null; then
		echo "Checksum check failed. Exiting."
		exit 1
		else
			echo -e "Checksum check passed. Continuing.\n\n\n"
	fi
else
	echo "CAUTION: No checksum file found, continue? (y/n) (NOT RECOMMENDED)"
while true; do
	read -p "" yn
	case $yn in
		[Yy]* ) echo -e "Answered: $yn\nContinuing"; break;;
		[Nn]* ) echo -e "Answered: $yn\nExiting"; exit;;
		* ) echo -e "Answered: $yn\nPlease answer yes or no." ;;
	esac
done
fi
# check if there is a second parameter
if ! [ -z "$2" ]; then
	echo "ERROR: Script only accepts one parameter (were spaces used in name?)"
	exit 1
fi

# check if paramter is not null
if [ -z "$1" ]; then
	echo "ERROR: Please provide a project name"
	exit 1
fi

# check if project already exists
if [ -d "$1" ]; then
	echo "ERROR: Project already exists"
	exit 1
fi

# check if name has spaces
if [[ "$1" =~ " " ]]; then
	echo "ERROR: Project name cannot contain spaces"
	exit 1
fi

# create yes/no prompt to accept project name
echo "Create project $1? (y/n)"
# while loop to choose answer
while true; do
	read -p "" yn
	case $yn in
		[Yy]* ) echo -e "Answered: $yn\nContinuing"; break;;
		[Nn]* ) echo -e "Answered: $yn\nExiting"; exit;;
		* ) echo -e "Answered: $yn\nPlease answer yes or no." ;;
	esac
done

# create project
mkdir $1
mkdir -p ./$1/src/bin
mkdir -p ./$1/src/utils
cat << EOF > "./$1/Cargo.toml"
[package]
name = "$1"
version = "0.1.0"
edition = "2021"

# See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

[dependencies]
clap = { version = "3.2.20", features = ["derive"] }
lazy_static = "1.4.0"
semver = "1.0.13"
sentry = { version = "0.27.0", features = ["panic", "tracing"] }
sentry-tracing = "0.27.0"
tracing = "0.1.36"
tracing-subscriber = "0.3.15"
undo = "0.47.2"
#tokio = { version = "1.21.0", features = ["full"] }
#rayon = "1.5.3"

[[bin]]
name = "$1"
path = "src/bin/main.rs"

EOF
echo "\"./$1/Cargo.toml\" created"

cat << EOF > "./$1/src/bin/main.rs"
#![warn(
    clippy::pedantic,
    clippy::nursery,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::perf
)]

use $1::utils::glitchtip::*;

use clap::Parser;
use lazy_static::lazy_static;
use std::env;

use tracing::{debug, error, info, warn};

#[derive(Parser)]
#[clap(author,version,about, long_about = None)]
struct Cli {
    #[clap(short = 'g', long = "glitchtip_dsn")]
    glitchtip_dsn: Option<String>,
    #[clap(short = 'p', long = "projectname", default_value = "$1")]
    project_name: String,
    #[clap(short = 'w', long = "width", default_value = "10")]
    width: usize,
    #[clap(short = 'h', long = "height", default_value = "5")]
    height: usize,
}
lazy_static! {
    static ref CLI_ARGS: Cli = Cli::parse();
}

fn main() {
    //TODO: Implement undo feature for better user experience
    println!("Launching project: {}", &CLI_ARGS.project_name);
    match &CLI_ARGS.glitchtip_dsn {
        Some(dsn) => {
            env::set_var("GLITCHTIP_DSN", dsn);
        }
        None => {
            println!("DEBUG: No (g)litchtip_dsn parameter used");
        }
    }

    init_glitchtip_reporter();

    debug!(
        d_string = "test debug string",
        ?CLI_ARGS.project_name,
        "debug! check"
    );
    info!("info! check [{}]", &CLI_ARGS.project_name);
    warn!("warn! check [{}]", &CLI_ARGS.project_name);
    error!("error! check [{}]", &CLI_ARGS.project_name);
}
EOF
echo "\"./$1/src/bin/main.rs\" created"

cat << EOF > "./$1/src/lib.rs"
pub mod utils;
EOF
cat << EOF > "./$1/src/utils.rs"
pub mod glitchtip;
EOF
cat << EOF > "./$1/src/utils/glitchtip.rs"
use sentry::IntoDsn;
use std::env;

use tracing::{error, info, warn};
use tracing_subscriber::prelude::*;

pub fn init_glitchtip_reporter() {
    //=========================================================
    //Set up tracing and error reporting
    //=========================================================

    let glitchtip_dsn = match env::var("GLITCHTIP_DSN") {
        Ok(dsn) => {
            info!("Found GLITCHTIP_DSN environment variable");
            match dsn.into_dsn() {
                Ok(value) => {
                    info!("Parsed into DSN successfully");
                    value
                }
                Err(err) => {
                    error!("Error converting GLITCHTIP_DSN string to dsn: {}", err);
                    None
                }
            }
        }
        Err(err) => {
            error!("Failed to get GLITCHTIP_DSN environment variable: {}", err);
            None
        }
    };
    let sentry = sentry::init(sentry::ClientOptions {
        dsn: glitchtip_dsn,
        traces_sample_rate: 1.0,
        ..sentry::ClientOptions::default()
    });

    if sentry.is_enabled() {
        sentry::configure_scope(|scope| {
            scope.set_level(Some(sentry::Level::Warning));
        });
        tracing_subscriber::registry()
            .with(tracing_subscriber::fmt::layer())
            .with(sentry::integrations::tracing::layer())
            .init();
        info!("Sentry is enabled");
    } else {
        tracing_subscriber::registry()
            .with(tracing_subscriber::fmt::layer())
            .init();
        warn!("Sentry is disabled");
    }
    //=========================================================
}
EOF

cat << 'EOF' > "./$1/cliff.toml"
# configuration file for git-cliff (0.1.0)

[changelog]
# changelog header
header = """
# Changelog\n
All notable changes to this project will be documented in this file.\n
"""
# template for the changelog body
# https://tera.netlify.app/docs/#introduction
body = """
{% if version %}\
    ## [{{ version | trim_start_matches(pat="v") }}] - {{ timestamp | date(format="%Y-%m-%d") }}
{% else %}\
    ## [unreleased]
{% endif %}\
{% if previous %}\
    {% if previous.commit_id %}
        [{{ previous.commit_id | truncate(length=7, end="") }}]({{ previous.commit_id }})...\
            [{{ commit_id | truncate(length=7, end="") }}]({{ commit_id }})
    {% endif %}\
{% endif %}\
{% for group, commits in commits | group_by(attribute="group") %}
    ### {{ group | upper_first }}
    {% for commit in commits %}
        - {{ commit.message | upper_first }} ([{{ commit.id | truncate(length=7, end="") }}]({{ commit.id }}))\
          {% for footer in commit.footers -%}
            , {{ footer.token }}{{ footer.separator }}{{ footer.value }}\
          {% endfor %}\
    {% endfor %}
{% endfor %}\n
"""
# remove the leading and trailing whitespace from the template
trim = true
# changelog footer
footer = """
<!-- generated by git-cliff -->
"""

[git]
# parse the commits based on https://www.conventionalcommits.org
conventional_commits = true
# filter out the commits that are not conventional
filter_unconventional = true
# process each line of a commit as an individual commit
split_commits = false
# regex for parsing and grouping commits
commit_parsers = [
    { message = "^feat", group = "Features"},
    { message = "^fix", group = "Bug Fixes"},
    { message = "^doc", group = "Documentation"},
    { message = "^perf", group = "Performance"},
    { message = "^refactor", group = "Refactor"},
    { message = "^style", group = "Styling"},
    { message = "^test", group = "Testing"},
    { message = "^chore\\(release\\): prepare for", skip = true},
    { message = "^chore", group = "Miscellaneous Tasks"},
    { body = ".*security", group = "Security"},
]
# filter out the commits that are not matched by commit parsers
filter_commits = false
# glob pattern for matching git tags
tag_pattern = "v[0-9]*"
# regex for skipping tags
skip_tags = "v0.1.0-beta.1"
# regex for ignoring tags
ignore_tags = ""
# sort the tags chronologically
date_order = false
# sort the commits inside sections by oldest/newest order
sort_commits = "newest"
EOF
echo "\"./$1/cliff.toml\" created"

cat << EOF > "./$1/launch_debugger.toml"
#!/bin/bash
ugdb --gdb=rust-gdb target/debug/$1
EOF
echo "\"./$1/launch_debugger.toml\" created"

cat << EOF > "./$1/clippy_fix.toml"
#!/bin/bash
cargo clippy --fix --allow-dirty -- -W clippy::pedantic -W clippy::nursery -W clippy::unwrap_used -W clippy::expect_used
EOF
echo "\"./$1/clippy_fix.toml\" created"

cat << EOF > "./$1/README.md"
# $1

## Author(s)
- [@gianpdev](https://www.twitter.com/gianpdev)
EOF
echo "\"./$1/README.md\" created"

cat << EOF > "./$1/.gitignore"
build/*
target/*
node_modules/*
*.pdb
*.log
EOF
echo "\"./$1/.gitignore\" created"

echo "Project: \"$1\" created"
