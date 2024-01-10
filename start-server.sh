#!/bin/bash
set -e 

percentBar ()  { 
    local prct totlen=$((8*$2)) lastchar barstring blankstring;
    printf -v prct %.2f "$1"
    ((prct=10#${prct/.}*totlen/10000, prct%8)) &&
        printf -v lastchar '\\U258%X' $(( 16 - prct%8 )) ||
            lastchar=''
    printf -v barstring '%*s' $((prct/8)) ''
    printf -v barstring '%b' "${barstring// /\\U2588}$lastchar"
    printf -v blankstring '%*s' $(((totlen-prct)/8)) ''
    printf -v "$3" '%s%s' "$barstring" "$blankstring"
}
percent(){ local p=00$(($1*100000/$2));printf -v "$3" %.2f ${p::-3}.${p: -3};}
displaySleep() {
    local -i refrBySeconds=50
    local -i _start=${EPOCHREALTIME/.} reqslp target crtslp crtp cols cpos dlen
    local strng percent prctbar tleft
    [[ $COLUMNS ]] && cols=${COLUMNS} || read -r cols < <(tput cols)
    refrBySeconds=' 1000000 / refrBySeconds '
    printf -v strng %.6f $1
    printf '\E[6n' && IFS=\; read -sdR _ cpos
    dlen=${#strng}-1  cols=' cols - dlen - cpos -1 '
    printf \\e7
    reqslp=10#${strng/.} target=reqslp+_start
    for ((;${EPOCHREALTIME/.}<target;)){
        crtp=${EPOCHREALTIME/.}
        crtslp='( target - crtp ) > refrBySeconds? refrBySeconds: target - crtp'
        strng=00000$crtslp  crtp+=-_start
        printf -v strng %.6f ${strng::-6}.${strng: -6}
        percent $crtp $reqslp percent
        percentBar $percent $cols prctbar
        tleft=00000$((reqslp-crtp))
        printf '\e8\e[36;48;5;23m%s\e[0m%*.4fs' \
               "$prctbar" "$dlen" ${tleft::-6}.${tleft: -6}
        IFS= read -rsn1 -t $strng ${2:-_} && { echo; return;}
    }
    percentBar 100 $cols prctbar
    printf '\e8\e[36;48;5;30m%s\e[0m%*.4fs\n' "$prctbar" "$dlen" 0
}

updateImage () {
    # Define the age limit in seconds (2 days)
    AGE_LIMIT=$((10*24*60*60))

    # Get current date in seconds
    CURRENT_TIME=$(date +%s)
    # Loop through each container named 'pdf-tools'
    docker ps -a --format "{{.ID}} {{.CreatedAt}}" --filter "name=pdf-tools" | while read -r CONTAINER_ID CREATED_AT; do 
        
        FORMATTED_DATE=$(echo "$CREATED_AT" | awk '{print $1 " " $2 " " $3}')       

        CONTAINER_TIME=$(date -d "$FORMATTED_DATE" +%s)

        # Calculate age of the container
        AGE=$((CURRENT_TIME - CONTAINER_TIME))
        # Check if age is greater than limit
        if [ "$AGE" -gt "$AGE_LIMIT" ]; then
            echo "Container $CONTAINER_ID named 'pdf-tools' is older than 2 days. Stopping and replacing the image."

            docker stop "$CONTAINER_ID"
            docker rm "$CONTAINER_ID"

            # Pull the latest image and run a new container
            docker pull frooodle/s-pdf:latest
            # docker run --name pdf-tools frooodle/s-pdf:latest
            # Add any additional run options or commands needed
        else
            echo -e "Latest Image is being used!"
        fi
    done


}
runApp ()  { 
    echo "Running Docker Container..."
    # docker start pdf-tools
    updateImage 

    # Check if the container 'pdf-tools' exists
    if docker ps -a | grep -q 'pdf-tools'; then
        echo "Container 'pdf-tools' exists. Starting the container..."
        docker start pdf-tools
        displaySleep 15
        docker logs -t pdf-tools
        sleep 5

    else
        echo "Container 'pdf-tools' does not exist. Running a new container..."
        docker pull frooodle/s-pdf:latest
        MSYS_NO_PATHCONV=1 docker run -d \
          -p 8080:8080 \
          -v /c/Users/Shitij/Desktop/projects/pdf-tools/run/tessdata:/usr/share/tesseract-ocr/5/tessdata \
          -v /c/Users/Shitij/Desktop/projects/pdf-tools/run/configs:/configs \
          -v /c/Users/Shitij/Desktop/projects/pdf-tools/run/logs:/logs \
          -e DOCKER_ENABLE_SECURITY=true \
          --name pdf-tools \
            frooodle/s-pdf:latest
        
        displaySleep 50
        docker logs -t pdf-tools

        # docker logs -t -f pdf-tools
    fi

    echo "Opening localhost in browser..."
    firefox http://localhost:8080
}

# Check if Docker is running
docker_process=$(tasklist | grep -i "docker") || true

if [ -z "$docker_process" ]; then
    echo "Docker Desktop is not running. Starting Docker Desktop..."
    "/c/Program Files/Docker/Docker/Docker Desktop.exe" &
    echo "Docker Desktop start command issued."
else
    echo "Docker Desktop is already running!"
fi

if ! docker ps | grep pdf-tools &>/dev/null; then
    echo "Container is not running!"
    running=false
else
    echo "pdf-tools Container is running!"
    running=true
fi

echo "Do you want to start(y) or stop(n) pdf-tools (y/n)?: "
read answer

if [ "$answer" = "n" ]; then
    if [ "$running" = true ];then
        docker stop pdf-tools
        echo "Container stopped."
        docker ps -a 
    else
        echo "Container is already stopped!!"
    fi
elif [ "$answer" = "y" ]; then
    if [ "$running" = false ];then
        runApp
    else
        echo "Container is already running!"
        echo "Open http://localhost:8080"
    fi
else
    echo "Invalid Input!"
fi
