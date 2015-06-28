#include "api_robot2.h"/*API control*/



void _start(void){
	unsigned int i;
        for (i = 0; i < 5000000; i++){}
	set_time(5);
	get_time(); /* Será usado o GDB para verificar o valor */

}

