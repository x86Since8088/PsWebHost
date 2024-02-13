
            # get post data.
            $data = extract $request

            # get the submitted name.
            $name = $data.item('person')

            # render the 'FormResponse' snippet, passing the name.
            $page = render $FormResponse @{name = $name}

            # embed the snippet into the template.
            return (render (gc (Get-HTMLTemplate_WS)) $page)
        
