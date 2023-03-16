# Architecture Decision of defined entrypoints for scan modules

The current architecture relies on the code pulling a lot of runtime-critical data from environment variables.
This is a volatile setup:
 * When ENV variables are renamed in the job runner configuration, we have to find every occurence of the variable and adapt it
 * Typos lead to missing data
 * There is no check with a defined error state when a variable is empty

 ## Proposed change

 Each module should be called with named parameters that are checked before the module runs and lead to well-defined errors if data is missing or malformed. That way variable names only have to be consistent inside the runer configuration and the modules operate within their own namespaces.
 Well-defined errors also aid in monitoring, reporting, and debugging as the job will automatically fail when mis-configured.

## Example code

Bash has a builtin to parse arguments: `getopt`. This could be use to parse command-line arguments, fall back to defaults, and perform error handling.
The following example codes uses the malware scanneer module as an example:

```shell
#!/bin/bash

# Initialize variables with default values
MAX_FILESIZE="4000M"
IMAGE_BY_HASH=""
IMAGE_TAR_PATH=""
ARTIFACTS_PATH=""

# Parse command-line options
while getopts "i:t:s:a:" opt; do
  case $opt in
    i)
      IMAGE_BY_HASH="$OPTARG"
      ;;
    t)
      IMAGE_TAR_PATH="$OPTARG"
      ;;
    s)
      MAX_FILESIZE="$OPTARG"
      ;;
    a)
      ARTIFACTS_PATH="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Check if any parameter is empty and exit with an error if it is
if [[ -z "$IMAGE_BY_HASH" || -z "$IMAGE_TAR_PATH" || -z "$ARTIFACTS_PATH" ]]; then
  echo "Error: one or more parameters is empty" >&2
  exit 1
fi
```

Other than the binary `getopt`, the builtin `getopts` does not support parameters in long form. But as a builtin, has no further dependencies than `bash` itself.
Therefore this would be a simple code change with no change to the images.