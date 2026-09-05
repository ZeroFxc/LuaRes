#include <stdio.h>
#include <string.h>
int main(){
    double v=370.5;
    unsigned char b[8];
    memcpy(b,&v,8);
    for(int i=0;i<8;i++) printf("%02x ",b[i]);
    printf("\n");
    return 0;
}
