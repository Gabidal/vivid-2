#Made by Gabriel Golzar: 17/11/2021
#Original DOcker system, check https://github.com/Gabidal/Evie/blob/master/H/Docker/Docker.h

#Vivid doesn't have pairs, so bear with me.
Translator{
    header: String
    function: Link

    init(func: Link, head: String){
        header = head
        function = func
    }
}

#hold the translators captive, this is for optimisation and preventing,
#re implementing the translator list of lambdas every time docker is made for single file include.
namepsace DOCKER{
    translators: List<Translator>
    default_translator: Translator
}

Docker{
    file_name: String
    working_dir: String

    init(name: String){
        file_name = name


    }

    #This function loops through the translators and calls the function of the translator, if the header matches.
    #The matching header is gotten from opening the file from the file_name, and taken the first 10 bytes from that file.
    #The header is then compared to the header of the translator, if it matches, the function of the translator is called.
    #If the header doesn't match, the function is skipped.
    #The function is called with the file name.
    #If none of the functions are called, then use the default translator.
    #The file is then closed.
    find_right_translator(){
        file = open(file_name, O_RDONLY)
        header = read(file, 10)
        loop(i = 0; i < DOCKER.translators.size(); i++){
            if(DOCKER.translators[i].header == header){
                DOCKER.translators[i].function(file_name)
                close(file)
                return
            }
        }
        DOCKER.default_translator.function(file_name)
        close(file)
    }

    #this function gets the path from the filename and puts the path into working_dir
    update_path(){
        last_index_of_slash = filename.last_index_of(/)
        if last_index_of_slash == -1{
            working_dir = "./"
        }
        working_dir = filename.slice(0, Last_index_of_slash)
    }
}