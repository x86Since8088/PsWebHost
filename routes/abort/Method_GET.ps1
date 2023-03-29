            $Content = '<h1>Abort Command Received</h1>' +
                '<p>Process Info</p>' + 
                (Convert-ObjectToHTMLTable -InputObject (get-process -id $PID))

			render (Get-Content (Get-HTMLTemplate_WS)) $content
			
            $response.close();
            $listener.stop();
