#include 'hbsocket.ch'

//	--------------------------------------------------------- //

function Api_Ollama( oDom )

	local cModel 		:= oDom:Get( 'model' )
	LOCAL cQuestion 	:= oDom:Get( 'myquestion' )
	local cModelName	:= OllamaKey2Name( cModel )
	LOCAL bReq 		:= {|cValue| GetValueStream( oDom, cValue ) }
	LOCAL oIA			:= TOLlama():New( cModelName )	
	LOCAL cResponse 	:= oIA:SendStream( cQuestion, bReq )
	
	IF !empty( cResponse )
		oDom:SetError( cResponse )
	ENDIF			
	
	oDom:Set( 'btn', 'Send' )
	
	oDom:Enable( 'model' )
	oDom:Enable( 'myquestion' )
	oDom:Enable( 'btn' )
	
	oDom:Focus( 'myquestion' )

retu oDom:Send() 

//	--------------------------------------------------------- //

static function GetValueStream( oDom, cBuffer ) 

    local lSuccess 	:= .f.
    local cValue 		:= ''
    local hResponse

    hb_jsonDecode( cBuffer, @hResponse )
   
    //_d( hResponse )
   
    if HB_HHasKey( hResponse, 'error' )   
		cValue := hResponse[ "error" ]
	else
		cValue := hResponse[ "message" ][ "content" ]
		lSuccess := .t.
	endif

	oDom:SendSocketJS( 'ShowProcess', { 'success' => lSuccess, 'prompt' => cValue } )

retu cValue

//	--------------------------------------------------------- //
