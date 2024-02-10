#!/bin/bash

# Help function
Help()
{
   # Display Help
   echo "This script builds the DFIR-IRIS module of the current directory and installs it to DFIR-IRIS. If you run it for the first time or change something in the module configuration template make sure to run the -a switch."
   echo
   echo "Syntax: ./buildnpush2iris [-a|h]"
   echo "options:"
   echo "a     Also install the module to the iris-web_app_1 container. Only required on initial install or when changes to config template were made."
   echo "h     Print this Help."
   echo
}

# Function to run the build and push process
Run()
{
    echo "[BUILDnPUSH2IRIS] Starting the build and push process.."

    # Build the Python wheel package
    python3.9 setup.py bdist_wheel

    # Find the latest module file
    latest=$(find ./dist -type f -name '*.whl' -printf "%T@ %p\n" | sort -n | tail -1 | cut -d' ' -f2)

    # Check if the latest module file exists
    if [ ! -f "$latest" ]; then
        echo "[BUILDnPUSH2IRIS] No module file found in ./dist"
        exit 1
    fi

    echo "[BUILDnPUSH2IRIS] Found latest module file: $latest"

    # Copy module file to worker container
    docker cp "$latest" iriswebapp_worker:/iriswebapp/dependencies/

    # Install module in worker container
    docker exec -it iriswebapp_worker /bin/sh -c "pip3 install /iriswebapp/dependencies/$(basename $latest) --force-reinstall"

    # Restart worker container
    docker restart iriswebapp_worker

    if [ "$a_Flag" = true ]; then
        # Copy module file to app container
        docker cp "$latest" iriswebapp_app:/iriswebapp/dependencies/

        # Install module in app container
        docker exec -it iriswebapp_app /bin/sh -c "pip3 install /iriswebapp/dependencies/$(basename $latest) --force-reinstall"

        # Restart app container
        docker restart iriswebapp_app
    fi

    echo "[BUILDnPUSH2IRIS] Completed!"
}

# Initialize flag
a_Flag=false

# Parse command-line options
while getopts ":ha" option; do
   case $option in
      h) # Display Help
         Help
         exit;;
      a) # Install module to app container
         echo "[BUILDnPUSH2IRIS] Pushing to Worker and App container!"
         a_Flag=true
         Run
         exit;;
      \?) # Invalid option
         echo "ERROR: Invalid option"
         exit;;
   esac
done

# If the '-a' flag is not provided, install the module only to the worker container
echo "[BUILDnPUSH2IRIS] Pushing to Worker container only!"
Run
exit
