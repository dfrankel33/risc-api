# Data Export Script

## Input Parameters

- **ASSESSMENT_CODE** - RISC Assessment Code
- **API_KEY** - RISC Assessment API Key
- **USER_ID** - Email address of user authenticating
- **USER_PASSWORD** - Password of user authenticating
- **CUSTOMER_NAME** - Customer name, used in naming the output CSV file
- **OUTPUT_PATH** - Output path for resulting CSV file. If not specified, the output path will be the current working directory.

## Usage

```powershell
.\risc-data-export.ps1 -ASSESSMENT_CODE "ZzY45TlUIjc6rPk38jE6MTowOjE=" -API_KEY "rl4vb03be97e9835l02a87c617goe49a" -USER_ID "john.doe@company.com" -USER_PASSWORD "Myp@ssW0rd!" -CUSTOMER_NAME "Dunder Mifflin" -OUTPUT_PATH "~\Documents\ICMC-Outputs\"
```

## Foundations Assessment Requirements

- Required Stack Tags:
  - Application Type
  - Business Group
  - Business Critical
  - Sequence Preference
- Required Asset Tags:
  - Tier (values: Web, Database, App, Application)
- Required Tags on Stack OR Asset:
  - Presentation Layer Version
  - Business Layer Version
  - App Server Version
  - Web Server Version
  - Database Version

### Technically Coupled Applications

In order to properly identify Technically Coupled Applications, a "Shared DB" application stack must be leveraged.

- The Shared DB stack should only consist of Database servers that have dependencies across multiple applications
- The Shared DB stack name should include one of the following so the script can identify the stack.  The stack name can include any unique identifiers, numbers, etc. before or after the identifier
  - Shared DB - *example:* "Shared DB 001"
  - SharedDB - *example:* "001SharedDB"
  - Shared_DB - *example:* "Shared_DB_foobar"
- Any stacks with connectivity to the assets in the Shared DB stack will be identified as having Technically Coupled Applications
- Multiple Shared DB stacks may exist

## Script Decision Making

- The script will first gather all application Stack tags, ignoring stacks named "Isolated Devices", "No Connectivity", and any stack that starts with "RISC"
- The script will attempt to gather the following tags from the Stack. If any of these tags are not available on the Stack, the script will look for stack assets that use these tags.
  - Presentation Layer Version
  - Business Layer Version
  - App Server Version
  - Web Server Version
- The script will look for the Tier tag on stack assets to identify Web/App/DB assets and will retrieve the associated OS version details from the tagged asset(s)
- EOL/EOS data will be retrieved from Asset Issue Checks
- Dependant Apps will be identified from any connectivity between stacks
- Technically Coupled Applications will be identified as stacks that are sharing the same DB tier

## Output Format

The output of this script is a CSV file with the following headers:

- Application Name
- Application Type
- Business Group
- Business Critical
- Sequence Preference
- Presentation Layer Version
- Business Layer Version
- App Server Version
- App Server OS
- Web Server Version
- Web Server OS
- End of Life Hardware
- End of Support Software
- Dependant Applications
- Database Version
- Database OS
- Technically Coupled Applications
