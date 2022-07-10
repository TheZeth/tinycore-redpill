#!/usr/bin/env bash
set -uo pipefail

function showhelp() {
    cat <<EOF
$(basename ${0})

----------------------------------------------------------------------------------------
Usage: ${0} <Synology Model Name> <Options>

Options: postupdate, noconfig, noclean, manual

- postupdate : Option to patch the restore loop after applying DSM 7.1.0-42661 Update 2, no additional build required.

- noconfig: SKIP automatic detection change processing such as SN/Mac/Vid/Pid/SataPortMap of user_config.json file.

- noclean: SKIP the 💊   RedPill LKM/LOAD directory without clearing it with the Clean command. 
           However, delete the Cache directory and loader.img.

- manual: Options for manual extension processing and manual dtc processing in build action (skipping extension auto detection)

Please type Synology Model Name after ./$(basename ${0})

- for jot mode

./$(basename ${0}) DS918+
./$(basename ${0}) DS3617xs
./$(basename ${0}) DS3615xs
./$(basename ${0}) DS3622xs+
./$(basename ${0}) DVA3221
./$(basename ${0}) DS920+
./$(basename ${0}) DS1621+
./$(basename ${0}) DS2422+
./$(basename ${0}) DVA1622
./$(basename ${0}) DS1520+ (Not Suppoted)
./$(basename ${0}) FS2500 (Not Suppoted)

- for jun mode

./$(basename ${0}) DS918+J                                                                                                      
./$(basename ${0}) DS3617xsJ                                                                                                    
./$(basename ${0}) DS3615xsJ                                                                                                    
./$(basename ${0}) DS3622xs+J                                                                                                   
./$(basename ${0}) DVA3221J                                                                                                     
./$(basename ${0}) DS920+J                                                                                                      
./$(basename ${0}) DS1621+J 
./$(basename ${0}) DS2422+J  
./$(basename ${0}) DVA1622J (Not Suppoted)
./$(basename ${0}) DS1520+J
./$(basename ${0}) FS2500J

EOF

}

# Function READ_YN, cecho                                                                                        
# Made by FOXBI                                                                                                               
# 2022.04.14                                                                                                                  
#                                                                                                                             
# ==============================================================================                                              
# Y or N Function                                                                                                             
# ==============================================================================                                              
READ_YN () { # $1:question $2:default                                                                                         
   read -n1 -p "$1" Y_N                                                                                                       
    case "$Y_N" in                                                                                                            
    y) Y_N="y"                                                                                                                
         echo -e "\n" ;;                                                                                                      
    n) Y_N="n"                                                                                                                
         echo -e "\n" ;;                                                                                                      
    q) echo -e "\n"                                                                                                           
       exit 0 ;;                                                                                                              
    *) echo -e "\n" ;;                                                                                                        
    esac                                                                                                                      
}                                                                                         

# ==============================================================================          
# Color Function                                                                          
# ==============================================================================          
cecho () {                                                                                
    if [ -n "$3" ]                                                                                                            
    then                                                                                  
        case "$3" in                                                                                 
            black  | bk) bgcolor="40";;                                                              
            red    |  r) bgcolor="41";;                                                              
            green  |  g) bgcolor="42";;                                                                 
            yellow |  y) bgcolor="43";;                                             
            blue   |  b) bgcolor="44";;                                             
            purple |  p) bgcolor="45";;                                                   
            cyan   |  c) bgcolor="46";;                                             
            gray   | gr) bgcolor="47";;                                             
        esac                                                                        
    else                                                                            
        bgcolor="0"                                                                 
    fi                                                                              
    code="\033["                                                                    
    case "$1" in                                                                    
        black  | bk) color="${code}${bgcolor};30m";;                                
        red    |  r) color="${code}${bgcolor};31m";;                                
        green  |  g) color="${code}${bgcolor};32m";;                                
        yellow |  y) color="${code}${bgcolor};33m";;                                
        blue   |  b) color="${code}${bgcolor};34m";;                                
        purple |  p) color="${code}${bgcolor};35m";;                                
        cyan   |  c) color="${code}${bgcolor};36m";;                                
        gray   | gr) color="${code}${bgcolor};37m";;                                
    esac                                                                            
                                                                                                                                                                    
    text="$color$2${code}0m"                                                                                                                                        
    echo -e "$text"                                                                                                                                                 
}   


function checkinternet() {

    echo -n "Checking Internet Access -> "
    nslookup github.com 2>&1 >/dev/null
    if [ $? -eq 0 ]; then
        echo "OK"
    else
        cecho g "Error: No internet found, or github is not accessible"
        exit 99
    fi

}

function getlatestmshell() {

    echo -n "Checking if a newer mshell version exists on the repo -> "

    if [ ! -f $mshellgz ]; then
        curl -s --location "$mshtarfile" --output $mshellgz
    fi

    curl -s --location "$mshtarfile" --output latest.mshell.gz

    CURRENTSHA="$(sha256sum $mshellgz | awk '{print $1}')"
    REPOSHA="$(sha256sum latest.mshell.gz | awk '{print $1}')"

    if [ "${CURRENTSHA}" != "${REPOSHA}" ]; then
        echo -n "There is a newer version of m shell script on the repo should we use that ? [yY/nN]"
        read confirmation
        if [ "$confirmation" = "y" ] || [ "$confirmation" = "Y" ]; then
            echo "OK, updating, please re-run after updating"
            cp -f /home/tc/latest.mshell.gz /home/tc/$mshellgz
            rm -f /home/tc/latest.mshell.gz
            tar -zxvf $mshellgz
            echo "Updating m shell with latest updates"
            exit
        else
            rm -f /home/tc/latest.mshell.gz
            return
        fi
    else
        echo "Version is current"
        rm -f /home/tc/latest.mshell.gz
    fi

}

function macgen() {
echo
    mac2="$(generateMacAddress $1)"

    cecho y "Mac2 Address for Model $1 : $mac2 "

    macaddress2=$(echo $mac2 | sed -s 's/://g')

    sed -i "/\"extra_cmdline\": {/c\  \"extra_cmdline\": {\"mac2\": \"$macaddress2\",\"netif_num\": \"2\", "  user_config.json

    echo "After changing user_config.json"      
    cat user_config.json

}

function generateMacAddress() {
    printf '00:11:32:%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))

}

# Function EXDRIVER_FN
# Made by FOXBI
# 2022.04.14
# ==============================================================================
# Extension Driver Function
# ==============================================================================
function EXDRIVER_FN() {

    # ==============================================================================
    # Clear extension & install extension driver
    # ==============================================================================
    echo
    cecho c "Delete extension file..."
    sudo rm -rf ./redpill-load/custom/extensions/*
    echo
#    cecho c "Update ext-manager..."
#    ./redpill-load/ext-manager.sh update

    echo    
    cecho r "Add to Driver Repository..."
    echo
    READ_YN "Do you want Add Driver? Y/N :  "
    ICHK=$Y_N
    while [ "$ICHK" == "y" ] || [ "$ICHK" == "Y" ]
    do
        ICNT=
        JCNT=
        IRRAY=()
        while read LINE_I;
        do
            ICNT=$(($ICNT + 1))
            JCNT=$(($ICNT%5))
            if [ "$JCNT" -eq "0" ]
            then
                IRRAY+=("$ICNT) $LINE_I\ln");
            else
                IRRAY+=("$ICNT) $LINE_I\lt");
            fi
        done < <(curl --no-progress-meter https://github.com/pocopico/rp-ext | grep "raw.githubusercontent.com" | awk '{print $2}' | awk -F= '{print $2}' | sed "s/\"//g" | awk -F/ '{print $7}')
            echo ""
            echo -e " ${IRRAY[@]}" | sed 's/\\ln/\n/g' | sed 's/\\lt/\t/g'
            echo ""
            read -n100 -p " -> Select Number Enter (To select multiple, separate them with , ): " I_O
            echo ""
            I_OCHK=`echo $I_O | grep , | wc -l`
            if [ "$I_OCHK" -gt "0" ]
            then
                while read LINE_J;
                do
                    j=$((LINE_J - 1))
                    IEXT=`echo "${IRRAY[$j]}" | sed 's/\\\ln//g' | sed 's/\\\lt//g' | awk '{print $2}'`

		    if [ $TARGET_REVISION == "42218" ] ; then
		    	if [ $MSHELL_ONLY_MODEL == "Y" ] ; then
			    ./rploader.sh ext ${TARGET_PLATFORM}-7.0.1-${TARGET_REVISION}-JUN add https://raw.githubusercontent.com/PeterSuh-Q3/rp-ext/master/$IEXT/rpext-index.json
			else
                            ./rploader.sh ext ${TARGET_PLATFORM}-7.0.1-42218-JUN add https://raw.githubusercontent.com/pocopico/rp-ext/master/$IEXT/rpext-index.json    
			fi	
		    else
			if [ $SYNOMODEL == "ds2422p_42661" ] ; then
			    ./rploader.sh ext ${TARGET_PLATFORM}-7.1.0-${TARGET_REVISION} add https://raw.githubusercontent.com/PeterSuh-Q3/rp-ext/master/$IEXT/rpext-index.json
			else
			    ./rploader.sh ext ${TARGET_PLATFORM}-7.1.0-${TARGET_REVISION} add https://raw.githubusercontent.com/pocopico/rp-ext/master/$IEXT/rpext-index.json			
			fi
	    	    fi

                done < <(echo $I_O | tr ',' '\n')
            else
                I_O=$(($I_O - 1))
                for (( i = 0; i < $ICNT; i++)); do
                    if [ "$I_O" == $i ]
                    then
                        export IEXT=`echo "${IRRAY[$i]}" | sed 's/\\\ln//g' | sed 's/\\\lt//g' | awk '{print $2}'`
                    fi
                done

                if [ $TARGET_REVISION == "42218" ] ; then                                                                                                                                    
		    	if [ $MSHELL_ONLY_MODEL == "Y" ] ; then
			    ./rploader.sh ext ${TARGET_PLATFORM}-7.0.1-${TARGET_REVISION}-JUN add https://raw.githubusercontent.com/PeterSuh-Q3/rp-ext/master/$IEXT/rpext-index.json
			else
                            ./rploader.sh ext ${TARGET_PLATFORM}-7.0.1-42218-JUN add https://raw.githubusercontent.com/pocopico/rp-ext/master/$IEXT/rpext-index.json    
			fi	
                else                                                                                                                                                                         
			if [ $SYNOMODEL == "ds2422p_42661" ] ; then
			    ./rploader.sh ext ${TARGET_PLATFORM}-7.1.0-${TARGET_REVISION} add https://raw.githubusercontent.com/PeterSuh-Q3/rp-ext/master/$IEXT/rpext-index.json
			else
			    ./rploader.sh ext ${TARGET_PLATFORM}-7.1.0-${TARGET_REVISION} add https://raw.githubusercontent.com/pocopico/rp-ext/master/$IEXT/rpext-index.json			
			fi
                fi   

            fi
        echo
        READ_YN "Do you want add driver? Y/N :  "
        ICHK=$Y_N
    done
}
