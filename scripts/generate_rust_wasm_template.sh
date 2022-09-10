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

# check if name has - 
if [[ "$1" =~ "-" ]]; then
	echo "ERROR: Project name cannot contain dashes (-)"
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
dioxus = { version = "0.2.4", features = ["web"] }
lazy_static = "1.4.0"
semver = "1.0.13"
tracing = "0.1.36"
tracing-wasm = "^0.2"
wasm-bindgen = "^0.2.8"
console_error_panic_hook = "0.1.7"
undo = "0.47.2"
#tokio = { version = "1.21.0", features = ["full"] }
#rayon = "1.5.3"

[[bin]]
name = "$1"
path = "src/bin/main.rs"

[profile.release]
lto = true
opt-level = "s"
strip = "none"
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

use $1::app;

use clap::Parser;
use lazy_static::lazy_static;
use std::env;

use tracing::{debug, error, info, warn};

#[derive(Parser)]
#[clap(author,version,about, long_about = None)]
struct Cli {
    #[clap(short = 't', long = "token")]
    token: Option<String>,
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
    match &CLI_ARGS.token {
        Some(dsn) => {
            env::set_var("TOKEN", dsn);
        }
        None => {
            println!("DEBUG: No token parameter used");
        }
    }

	app::run();
}
EOF
echo "\"./$1/src/bin/main.rs\" created"

cat << EOF > "./$1/src/app.rs"
use crate::utils::wasm_tracing;
use dioxus::prelude::*;
use tracing::{debug, error, info, warn};
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn run() {
    wasm_tracing::init_tracing();
    info!("app.rs info!");
    warn!("app.rs warn!");
    error!("app.rs error!");
    dioxus::web::launch(hello_world);
}

fn hello_world(cx: Scope) -> Element {
    info!("Hello wasm info!");
    cx.render(rsx! {
        div {
            "Hello, wasm!"
        }
    })
}
EOF
cat << EOF > "./$1/src/lib.rs"
pub mod utils;
pub mod app;
EOF
cat << EOF > "./$1/src/utils/mod.rs"
pub mod wasm_tracing;
EOF
cat << EOF > "./$1/src/utils/wasm_tracing.rs"
use tracing::{debug, error, info, warn};
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn init_tracing() {
    console_error_panic_hook::set_once();
    tracing_wasm::set_as_global_default();

    debug!("debug! wasm_tracing.rs check");
    info!("info! wasm_tracing.rs check");
    warn!("warn! wasm_tracing.rs check");
    error!("error! wasm_tracing.rs check");
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

cat << EOF > "./$1/launch_debugger.sh"
#!/bin/bash
ugdb --gdb=rust-gdb target/debug/$1
EOF
echo "\"./$1/launch_debugger.sh\" created"

cat << EOF > "./$1/clippy_fix.sh"
#!/bin/bash
cargo clippy --fix --allow-dirty -- -W clippy::pedantic -W clippy::nursery -W clippy::unwrap_used -W clippy::expect_used
EOF
echo "\"./$1/clippy_fix.sh\" created"

cat << 'EOF' > "./$1/build_wasm_release.sh"
#!/bin/bash
# outputs build settings and wasm file size to log file
echo "=========================================" | tee -a ./wasm-release.log
echo -e "$(date +"[%s]%Y-%m-%d_%R:%S%z")" | tee -a ./wasm-release.log
echo "=========================================" | tee -a ./wasm-release.log
echo -e "$(cat Cargo.toml | grep version | head -n 1)\n$(cat Cargo.toml | grep lto | head -n 1)\n$(cat Cargo.toml | grep opt-level | head -n 1)\n$(cat Cargo.toml | grep "strip" | head -n 1)\n" | tee -a ./wasm-release.log

trunk build --release

echo -e "$(ls ./dist/*.wasm)" | tee -a ./wasm-release.log
echo -e "size: $(stat -c%s ./dist/*.wasm | numfmt --to=iec) [$(stat -c%s ./dist/*.wasm)]\n" | tee -a ./wasm-release.log
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^" | tee -a ./wasm-release.log

# outputs the size of the wasm file in bytes
echo -e "$(stat -c%s ./dist/*.wasm)B [$(stat -c%s ./dist/*.wasm | numfmt --to=iec)]$(date +"[%s]")[$(cat Cargo.toml | grep version | head -n 1 | sed 's/^[^=]*=//' | sed 's/\s//'), $(cat Cargo.toml | grep lto | head -n 1 | sed 's/^[^=]*=//' | sed 's/\s//'), $(cat Cargo.toml | grep opt-level | head -n 1 | sed 's/^[^=]*=//' | sed 's/\s//'), $(cat Cargo.toml | grep "strip" | head -n 1 | sed 's/^[^=]*=//' | sed 's/\s//')]" | tee -a ./wasm-sizes.log
EOF
echo "\"./$1/build_wasm_release.sh\" created"
chmod +x clippy_fix.sh launch_debugger.sh build_wasm_release.sh

cat << EOF > "./$1/README.md"
# $1

## Author(s)
- [@gianpdev](https://www.twitter.com/gianpdev)
EOF
echo "\"./$1/README.md\" created"

cat << EOF > "./$1/index.html"
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
  </head>
  <body>
    <div id="main"></div>
	<hr>
	<footer>
		<p><em>Project "$1"</em></p>
	</footer>
  </body>
</html>
EOF

cat << EOF > "./$1/.gitignore"
build/*
target/*
node_modules/*
dist/*
*.pdb
*.log
EOF
echo "\"./$1/.gitignore\" created"

echo "Project: \"$1\" created"
