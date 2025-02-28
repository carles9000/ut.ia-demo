#define VK_ESCAPE	 27

request DBFCDX
request TWEB
request CURL_VERSION
request _D

function main()

	hb_threadStart( @WebServer() )		
	hb_threadStart( @WebServerSocket() )

	while inkey(0) != VK_ESCAPE
	end

retu nil 

//	----------------------------------------------------------------------------/Set/
//	Config UT Server
//	----------------------------------------------------------------------------//

function WebServer()

	local oServer 	:= Httpd2()	

		oServer:SetPort( 81 )
		oServer:bInit 		:= {|hInfo| ShowInfo( hInfo ) }	

	//	Define Routes...			

		oServer:Route( '/'		, 'index.html' ) 																																	
		
		oServer:Route( 'ia_gemini'	, 'ia_gemini.html' )  												 												
		oServer:Route( 'ia_ollama'	, 'ia_ollama.html' )  
		
		
	//	-----------------------------------------------------------------------//	
	
	IF ! oServer:Run()
	
		? "=> Server error:", oServer:cError

		RETU 1
	ENDIF
	
RETURN 0

//	----------------------------------------------------------------------------//
//	Config WebSockets Server
//	----------------------------------------------------------------------------//

function WebServerSocket()

	local oServer := UWebSocket()	
	
	oServer:SetSSL( .F. )	
	oServer:SetPort( 9000 )
	

	oServer:bValidate := {|hParam| MyValidate(hParam) }
	
	//	-----------------------------------------------------------------------//	

	IF ! oServer:Run()
	
		? "=> WebServerSockets error:", oServer:cError

		RETU 1
	ENDIF	
	
RETURN 0


//	----------------------------------------------------------------------------//
//	SECURITY: 
//	This is where you can configure your security based on the token received.
//	----------------------------------------------------------------------------//
//	hParam -> Hash 
//	hParam[ 'scope' ]
//	hParam[ 'token' ]
//	----------------------------------------------------------------------------//

function MyValidate( hParam )
	
	if ! (  hParam[ 'token' ] == 'ABC-1234' )
		retu .f.
	endif	

retu .t. 

//----------------------------------------------------------------------------//

function ShowInfo( hInfo )

	QOut( 'Version Harbour...: ' + VERSION() + ' / ' + HB_BUILDDATE() )
	QOut( 'Version Curl......: ' + Curl_Version() )
	QOut( 'Compiler..........: ' + HB_COMPILER() )
	QOut( 'Port..............: ' + ltrim( str (hInfo[ 'port' ] ) ) )
	
	QOut( 'Escape for exit...' 	)
	


retu nil 

//----------------------------------------------------------------------------//

function OllamaGetModels( lLoadModelName )

	LOCAL hModels := {=>}
	
	hb_default( @lLoadModelName, .F. )

	USE 'data\ollama_models.dbf' SHARED NEW 	
	
	WHILE !EOF()
	
		IF lLoadModelName
			hModels[  Alltrim( FIELD->key ) ] :=  alltrim( FIELD->model )
		ELSE
			hModels[  Alltrim( FIELD->key ) ] :=  alltrim( FIELD->combo )
		ENDIF
		
		DbSkip()
	
	END

retu hModels

//----------------------------------------------------------------------------//

function OllamaKey2Name( cKey )

	LOCAL hModels := OllamaGetModels( .T. )
	
RETU HB_HGetDef( hModels, cKey, '' )

//----------------------------------------------------------------------------//
