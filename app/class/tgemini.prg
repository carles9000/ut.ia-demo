// Get your API key from https://aistudio.google.com/live

#include "hbclass.ch"
#include "hbcurl.ch"

#xcommand TRY  => BEGIN SEQUENCE WITH {| oErr | Break( oErr ) }
#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->
#xcommand FINALLY => ALWAYS

//----------------------------------------------------------------------------//

CLASS TGemini

   DATA   cKey   INIT ""
   DATA   cModel INIT "gemini-2.0-flash"
   DATA   cResponse
   DATA   cUrl   INIT "https://generativelanguage.googleapis.com/v1beta/models"
   DATA   cUploadUrl INIT "https://generativelanguage.googleapis.com/upload/v1beta/files"
   DATA   hCurl
   DATA   nError INIT 0
   DATA   nHttpCode INIT 0
   DATA   nTemperature INIT 0

   METHOD New( cKey, cModel )
   METHOD Send( uContent, cPrompt, bCallback )
   METHOD End()
   METHOD GetValue()
   METHOD UploadFile( cFileName, lDeleteAfter )

ENDCLASS

//----------------------------------------------------------------------------//

METHOD New( cKey, cModel ) CLASS TGemini

   if Empty( cKey )
      ::cKey = GetEnv( "GEMINI_API_KEY" )
   else
      ::cKey = cKey
   endif

   if ! Empty( cModel )
      ::cModel = cModel
   endif

   if Val( SubStr( Curl_Version_Info()[ 1 ], 1, RAt( ".", Curl_Version_Info()[ 1 ] ) - 1 ) ) - 8.10 > 0.2
      MsgAlert( "Please use an updated curl DLL" )
   endif    

   ::hCurl = curl_easy_init()

return Self

//----------------------------------------------------------------------------//

METHOD End() CLASS TGemini

   curl_easy_cleanup( ::hCurl )
   ::hCurl = nil

return nil

//----------------------------------------------------------------------------//

METHOD GetValue() CLASS TGemini

   local hResponse, uValue

   if ! Empty( ::cResponse )
      hb_jsonDecode( ::cResponse, @hResponse )
   endif

   if hb_isHash( hResponse )
      if hb_hHasKey( hResponse, "error" )
         uValue = "API Error: " + hResponse[ "error" ][ "message" ] + " (Code: " + hb_ntos( hResponse[ "error" ][ "code" ] ) + ")"
      elseif hb_hHasKey( hResponse, "candidates" ) .and. Len( hResponse[ "candidates" ] ) > 0
         TRY
            uValue = hResponse[ "candidates" ][ 1 ][ "content" ][ "parts" ][ 1 ][ "text" ]
         CATCH
            uValue = "Error: Unexpected response structure"
         END
      else
         uValue = "Error: No candidates in response"
      endif
   else
      uValue = "Error: Invalid response format"
   endif

return uValue

//----------------------------------------------------------------------------//

METHOD Send( uContent, cPrompt, bCallback ) CLASS TGemini

   local aHeaders, cJson, hRequest := {=>}, hContents := { => }, hGenerationConfig
   local cFileUri, cMimeType, lIsFile := .F., cUrlEndpoint
   local aFiles, nI, aParts := {}, cFileNameToUpload, cTempFile

   // Set default prompt if not specified
   if Empty( cPrompt )
      cPrompt = "what is this or solve this"
   endif

   // Check if uContent is an array
   if hb_isArray( uContent )
      aFiles = uContent
      for nI = 1 to Len( aFiles )
         if hb_isChar( aFiles[ nI ] ) .and. File( aFiles[ nI ] )
            cFileNameToUpload = aFiles[ nI ]
            cTempFile = nil
            // Create temporary .txt file for .prg and .ch
            if Lower( Right( aFiles[ nI ], 3 ) ) == "prg"
               cTempFile = hb_FNameMerge( hb_FNameDir( aFiles[ nI ] ), hb_FNameName( aFiles[ nI ] ), "txt" )
               hb_FCopy( aFiles[ nI ], cTempFile )
               cFileNameToUpload = cTempFile
            elseif Lower( Right( aFiles[ nI ], 2 ) ) == "ch"
               cTempFile = hb_FNameMerge( hb_FNameDir( aFiles[ nI ] ), hb_FNameName( aFiles[ nI ] ), "txt" )
               hb_FCopy( aFiles[ nI ], cTempFile )
               cFileNameToUpload = cTempFile
            endif
            cFileUri = ::UploadFile( cFileNameToUpload, !Empty( cTempFile ) )
            if Empty( cFileUri )
               if !Empty( cTempFile ) .and. File( cTempFile )
                  hb_FileDelete( cTempFile )
               endif
               return "Error uploading file: " + aFiles[ nI ]
            endif
            do case
               case Lower( Right( aFiles[ nI ], 3 ) ) == "png"
                  cMimeType = "image/png"
               case Lower( Right( aFiles[ nI ], 3 ) ) $ "jpg|jpeg"
                  cMimeType = "image/jpeg"
               case Lower( Right( aFiles[ nI ], 3 ) ) == "pdf"
                  cMimeType = "application/pdf"
               case Lower( Right( aFiles[ nI ], 3 ) ) == "txt"
                  cMimeType = "text/plain"
               case Lower( Right( aFiles[ nI ], 3 ) ) == "csv"
                  cMimeType = "text/csv"
               case Lower( Right( aFiles[ nI ], 3 ) ) == "prg"
                  cMimeType = "text/plain"
               case Lower( Right( aFiles[ nI ], 2 ) ) == "ch"
                  cMimeType = "text/plain"
               otherwise
                  if !Empty( cTempFile ) .and. File( cTempFile )
                     hb_FileDelete( cTempFile )
                  endif
                  return "Unsupported file type: " + aFiles[ nI ]
            endcase
            AAdd( aParts, { "fileData" => { "fileUri" => cFileUri, "mimeType" => cMimeType } } )
            if !Empty( cTempFile ) .and. File( cTempFile )
               hb_FileDelete( cTempFile )
            endif
         else
            return "Invalid file in array: " + aFiles[ nI ]
         endif
      next
      lIsFile = .T.
   elseif hb_isChar( uContent ) .and. File( uContent )
      lIsFile = .T.
      cFileNameToUpload = uContent
      cTempFile = nil
      // Create temporary .txt file for .prg and .ch
      if Lower( Right( uContent, 3 ) ) == "prg"
         cTempFile = hb_FNameMerge( hb_FNameDir( uContent ), hb_FNameName( uContent ), "txt" )
         hb_FCopy( uContent, cTempFile )
         cFileNameToUpload = cTempFile
      elseif Lower( Right( uContent, 2 ) ) == "ch"
         cTempFile = hb_FNameMerge( hb_FNameDir( uContent ), hb_FNameName( uContent ), "txt" )
         hb_FCopy( uContent, cTempFile )
         cFileNameToUpload = cTempFile
      endif
      cFileUri = ::UploadFile( cFileNameToUpload, !Empty( cTempFile ) )
      if Empty( cFileUri )
         if !Empty( cTempFile ) .and. File( cTempFile )
            hb_FileDelete( cTempFile )
         endif
         return ""
      endif
      do case
         case Lower( Right( uContent, 3 ) ) == "png"
            cMimeType = "image/png"
         case Lower( Right( uContent, 3 ) ) $ "jpg|jpeg"
            cMimeType = "image/jpeg"
         case Lower( Right( uContent, 3 ) ) == "pdf"
            cMimeType = "application/pdf"
         case Lower( Right( uContent, 3 ) ) == "txt"
            cMimeType = "text/plain"
         case Lower( Right( uContent, 3 ) ) == "csv"
            cMimeType = "text/csv"
         case Lower( Right( uContent, 3 ) ) == "prg"
            cMimeType = "text/plain"
         case Lower( Right( uContent, 2 ) ) == "ch"
            cMimeType = "text/plain"
         otherwise
            if !Empty( cTempFile ) .and. File( cTempFile )
               hb_FileDelete( cTempFile )
            endif
            return "Unsupported file type"
      endcase
      AAdd( aParts, { "fileData" => { "fileUri" => cFileUri, "mimeType" => cMimeType } } )
      if !Empty( cTempFile ) .and. File( cTempFile )
         hb_FileDelete( cTempFile )
      endif
   endif

   // Set URL endpoint based on whether streaming is requested
   cUrlEndpoint = iif( hb_isBlock( bCallback ), ":streamGenerateContent", ":generateContent" )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_POST, .T. )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_URL, ::cUrl + "/" + ::cModel + cUrlEndpoint + "?key=" + ::cKey )

   // Set headers
   aHeaders := { "Content-Type: application/json" }
   curl_easy_setopt( ::hCurl, HB_CURLOPT_HTTPHEADER, aHeaders )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_USERNAME, "" )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_DL_BUFF_SETUP )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_SSL_VERIFYPEER, .F. )

   // Build request contents
   hContents[ "role" ] = "user"
   if lIsFile
      hRequest[ "contents" ] = { { "role" => "user", "parts" => aParts } }
      if ! Empty( cPrompt )
         AAdd( hRequest[ "contents" ], { "role" => "user", "parts" => { { "text" => cPrompt } } } )
      endif
   else
      hContents[ "parts" ] = { { "text" => iif( hb_isChar( uContent ), uContent, cPrompt ) } }
      hRequest[ "contents" ] = { hContents }
   endif

   // Generation config
   hGenerationConfig = { "temperature" => ::nTemperature,;
                         "topK" => 40, "topP" => 0.95, "maxOutputTokens" => 8192,;
                         "responseMimeType" => "text/plain" }
   hRequest[ "generationConfig" ] = hGenerationConfig

   // Encode and send
   cJson = hb_jsonEncode( hRequest )
   curl_easy_setopt( ::hCurl, HB_CURLOPT_POSTFIELDS, cJson )

   // Set callback if provided
   if hb_isBlock( bCallback )
      curl_easy_setopt( ::hCurl, HB_CURLOPT_WRITEFUNCTION, bCallback )
   endif

   ::nError = curl_easy_perform( ::hCurl )
   curl_easy_getinfo( ::hCurl, HB_CURLINFO_RESPONSE_CODE, @::nHttpCode )

   if ::nError == HB_CURLE_OK
      ::cResponse = curl_easy_dl_buff_get( ::hCurl )
   else
      ::cResponse = "CURL Error code " + Str( ::nError )
   endif

return ::cResponse

//----------------------------------------------------------------------------//

METHOD UploadFile( cFileName, lDeleteAfter ) CLASS TGemini

   local pCurl, aPost := {}, hHash

   if hb_isPointer( pCurl := curl_easy_init() )

      curl_easy_setopt( pCurl, HB_CURLOPT_CUSTOMREQUEST, "POST" )
      curl_easy_setopt( pCurl, HB_CURLOPT_URL, ::cUploadUrl + "?key=" + ::cKey )
      curl_easy_setopt( pCurl, HB_CURLOPT_FOLLOWLOCATION, .T. )
      curl_easy_setopt( pCurl, HB_CURLOPT_DL_BUFF_SETUP )
      curl_easy_setopt( pCurl, HB_CURLOPT_SSL_VERIFYPEER, .F. )

      AAdd( aPost, { "file", hb_jsonEncode( { "display_name" => cFileName } ) } )
      AAdd( aPost, { nil, cFileName } )

      curl_easy_setopt( pCurl, HB_CURLOPT_MIMEPOST, aPost )

      if ( ::nError := curl_easy_perform( pCurl ) ) == HB_CURLE_OK
         hHash = hb_jsonDecode( ::cResponse := curl_easy_dl_buff_get( pCurl ) )
      else
         MsgAlert( "curl error: " + AllTrim( Str( ::nError ) ) )
      endif

      curl_easy_cleanup( pCurl )
   endif

   if hb_isHash( hHash )
      #ifndef __XHARBOUR__
         if hb_hHasKey( hHash, "file" ) .and. hb_hHasKey( hHash[ "file" ], "uri" )
      #else
         if HHasKey( hHash, "file" ) .and. HHasKey( hHash[ "file" ], "uri" )      
      #endif      
        return hHash[ "file" ][ "uri" ]
      endif
   endif

   if lDeleteAfter .and. File( cFileName )
      hb_FileDelete( cFileName )
   endif

return ""

//----------------------------------------------------------------------------//

static function MSgAlert( u )
	? u 
retu nil 

//----------------------------------------------------------------------------//