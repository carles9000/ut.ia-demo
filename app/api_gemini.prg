#include 'hbsocket.ch'

//	--------------------------------------------------------- //

function Api_Gemini( oDom )

	LOCAL cQuestion 	:= oDom:Get( 'myquestion' )
	LOCAL bReq 		:= {|cValue| GetValueStream( oDom, cValue ) }
	LOCAL oIA			:= TGemini():New( memoread( 'api_key.txt' ) )

	oIA:Send( nil, cQuestion, bReq )
	
	oDom:Set( 'btn', 'Send' )
	oDom:Enable( 'myquestion' )
	oDom:Enable( 'btn' )
	
	oDom:Focus( 'myquestion' )

retu oDom:Send() 

//	--------------------------------------------------------- //

static function GetValueStream( oDom, cBuffer ) 

   local lSuccess	:= .f.
   local cValue 	:= ''
   local hResponse

   if Left( cBuffer, 1 ) == ","
      cBuffer = SubStr( cBuffer, 2 )
   endif

   hb_jsonDecode( cBuffer, @hResponse )
   
   // _d( hResponse )
	
   if Empty( hResponse ) 
		retu nil
   endif
   
    if ValType( hResponse ) == "A" 
	
		if HB_HHasKey( hResponse[ 1 ], 'error' ) 
			cValue := hResponse[ 1 ][ 'error' ][ 'message' ]
		else
			cValue := hResponse[ 1 ][ "candidates" ][ 1 ][ "content" ][ "parts" ][ 1 ][ "text" ]
		endif
		
	else

		cValue 		:= hResponse[ "candidates" ][ 1 ][ "content" ][ "parts" ][ 1 ][ "text" ] 
		lSuccess	:= .t.		
      	  
   endif   

	oDom:SendSocketJS( 'ShowProcess', { 'success' => lSuccess, 'prompt' => cValue } )

retu cValue

