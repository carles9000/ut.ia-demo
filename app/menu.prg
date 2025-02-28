#include 'lib/tweb/tweb.ch'

function Menu( oWeb, cCrumbs )

	local oNav, cTitle 
	
	do case
		case cCrumbs == 'gemini' ; cTitle := 'Agent Gemini'
		case cCrumbs == 'ollama' ; cTitle := 'Agent Ollama'
		otherwise
			cTitle := 'Agents IA'
	endcase

	NAV oNav ID 'nav' TITLE '&nbsp' + cTitle LOGO 'files/images/mercury_mini.png' ;
		ROUTE '/' WIDTH 30 HEIGHT 30 OF oWeb		
		
	//	Sidebar

		MENU GROUP 'Agents' OF oNav		
			
			MENUITEM 'Agent Gemini (Red)'   	ICON '<i class="fa fa-database" aria-hidden="true"></i>' ROUTE 'ia_gemini'  ACTIVE ( cCrumbs == 'gemini' ) OF oNav
			MENUITEM 'Agent Ollama (Local)'  	ICON '<i class="fa fa-database" aria-hidden="true"></i>' ROUTE 'ia_ollama'  ACTIVE ( cCrumbs == 'ollama' ) OF oNav
	
		ENDMENU GROUP OF oNav	

retu nil
	