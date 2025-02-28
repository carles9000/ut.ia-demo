// Developed by FiveTech Software, using parts by Charles OhChul

#include "hbcurl.ch"
#include "hbclass.ch"

#xcommand TRY  => BEGIN SEQUENCE WITH {| oErr | Break( oErr ) }
#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->
#xcommand FINALLY => ALWAYS

//----------------------------------------------------------------------------//

CLASS TOLlama
    
   DATA   cModel
   DATA   cResponse
   DATA   cUrl
   DATA   hCurl
   DATA   nError INIT 0
   DATA   nHttpCode INIT 0

   METHOD New( cModel )
   METHOD Send( cPrompt )    
   METHOD SendStream( cPrompt, bWriteFunction )  
   METHOD SendImage( cImageFileName, cPrompt )   

   METHOD End()    
   METHOD GetValue( cHKey )    

ENDCLASS        

//----------------------------------------------------------------------------//

METHOD New( cModel ) CLASS TOLlama

   hb_default( @cModel, "deepseek-r1:14b" )

   ::cModel = cModel
   ::cUrl = "http://localhost:11434/api/chat"
   ::hCurl = curl_easy_init()
    
return Self    

//----------------------------------------------------------------------------//

METHOD End() CLASS TOLlama

    curl_easy_cleanup( ::hCurl )
    ::hCurl = nil

return nil    

//----------------------------------------------------------------------------//

METHOD GetValue( cHKey ) CLASS TOLlama

   local uValue := hb_jsonDecode( ::cResponse )

   hb_default( @cHKey, "content" )

   if cHKey == "content"
      TRY 
         uValue = uValue[ "message" ][ "content" ]
      CATCH
         uValue = uValue[ "error" ][ "message" ]
      END   
   endif

return uValue

//----------------------------------------------------------------------------//

METHOD Send( cPrompt ) CLASS TOLlama 

   local aHeaders, cJson, hRequest := { => }, hMessage := { => }
  

   curl_easy_setopt( ::hCurl, HB_CURLOPT_POST, .T. )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_URL, ::cUrl )

   aHeaders := { "Content-Type: application/json" }

   curl_easy_setopt( ::hCurl, HB_CURLOPT_HTTPHEADER, aHeaders )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_USERNAME, '' )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_DL_BUFF_SETUP )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_SSL_VERIFYPEER, .F. )

   hRequest[ "model" ]       = ::cModel
   hMessage[ "role" ]        = "user"
   hMessage[ "content" ]     = cPrompt
   hRequest[ "messages" ]    = { hMessage }
   hRequest[ "stream" ]      = .F.
   hRequest[ "temperature" ] = 0.5

   cJson = hb_jsonEncode( hRequest )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_POSTFIELDS, cJson )
   ::nError = curl_easy_perform( ::hCurl )
  
   curl_easy_getinfo( ::hCurl, HB_CURLINFO_RESPONSE_CODE, @::nHttpCode )
 

   if ::nError == HB_CURLE_OK
      ::cResponse = curl_easy_dl_buff_get( ::hCurl )
   else
      ::cResponse := "Error code " + Str( ::nError )
   endif
    
return ::cResponse

//----------------------------------------------------------------------------//

METHOD SendStream( cPrompt, bWriteFunction ) CLASS TOLlama 

   local aHeaders, cJson, hRequest := { => }, hMessage := { => }
 
   curl_easy_setopt( ::hCurl, HB_CURLOPT_POST, .T. )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_URL, ::cUrl )

   aHeaders := { "Content-Type: application/json" }

   curl_easy_setopt( ::hCurl, HB_CURLOPT_HTTPHEADER, aHeaders )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_USERNAME, '' )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_SSL_VERIFYPEER, .F. )

   // Habilitar modo streaming
   hRequest[ "model" ]       = ::cModel
   hMessage[ "role" ]        = "user"
   hMessage[ "content" ]     = cPrompt
   hRequest[ "messages" ]    = { hMessage }
   hRequest[ "stream" ]      = .T.  // ACTIVAR STREAMING
   hRequest[ "temperature" ] = 0.5

   cJson = hb_jsonEncode( hRequest )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_POSTFIELDS, cJson )

   // Configurar la función de callback para recibir tokens en tiempo real
   curl_easy_setopt( ::hCurl, HB_CURLOPT_WRITEFUNCTION, bWriteFunction )

   ::nError = curl_easy_perform( ::hCurl )

   curl_easy_getinfo( ::hCurl, HB_CURLINFO_RESPONSE_CODE, @::nHttpCode )

   if ::nError != HB_CURLE_OK
      ::cResponse := "Error: " + ltrim(Str( ::nError )) + ' ' + curl_easy_strerror( ::nError )
   endif

return ::cResponse

//----------------------------------------------------------------------------//

METHOD SendImage( cImageFileName, cPrompt ) CLASS TOLlama

   local aHeaders, cJson, cBase64Image, hRequest := {=>}, hMessage := { => }

   if ! File( cImageFileName )
      MsgAlert( "Image " + cImageFileName + " not found" )
      return nil
   endif

   hb_default( @cPrompt, "What is in this image?" )

   cBase64Image = hb_base64Encode( memoRead( cImageFileName ) )

   curl_easy_setopt( ::hCurl, HB_CURLOPT_POST, .T. )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_URL, ::cUrl )

   aHeaders := { "Content-Type: application/json" }

   curl_easy_setopt( ::hCurl, HB_CURLOPT_HTTPHEADER, aHeaders )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_USERNAME, "" )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_DL_BUFF_SETUP )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_SSL_VERIFYPEER, .F. )

   hRequest[ "model" ]    = ::cModel
   hMessage[ "role" ]     = "user"
   hMessage[ "content" ]  = cPrompt
   hMessage[ "images" ]   = { cBase64Image }
   hRequest[ "messages" ] = { hMessage }
   hRequest[ "stream" ]   = .F.   

   cJson := hb_jsonEncode( hRequest )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_POSTFIELDS, cJson )

   ::nError = curl_easy_perform( ::hCurl )
   curl_easy_getinfo( ::hCurl, HB_CURLINFO_RESPONSE_CODE, @::nHttpCode )

   if ::nError == HB_CURLE_OK
      ::cResponse = curl_easy_dl_buff_get( ::hCurl )
   else
      ::cResponse = "Error code " + Str( ::nError )
   endif

return ::cResponse

//----------------------------------------------------------------------------//

function msgalert( u )
	? u 
retu nil