#include <stdio.h>
#include <stdlib.h>
#include <string.h> 
#include "encoding.h"
#include "platform.h"
#include "headers/bits.h"

#define conv_start_addr         _AC(0xD0000000,UL)
#define convBuf(offset)         _REG32(conv_start_addr,offset)
#define memo_start_addr         _AC(0xC0000000,UL)
#define memo(offset)            _REG32(memo_start_addr,offset)


void testSRAM();

void Convolution(int image[][32],int image_m,int imge_n,
                    int weight[][9],int weight_m,int weight_n,
                    int result[][32][32],int result_x,int result_y,int result_z
);

void directConvolution(int image[][32],int image_m,int imge_n,
                        int weight[][9],int weight_m,int weight_n,
                        int result[][32][32],int result_x,int result_y,int result_z
);

int main(void)
{

    //testSRAM();

    // load the data to SRAM 
    int weight[16][9];
    int image[34][32];
    int result[16][32][32];
    int i=0,j=0;

    for(i=0;i<16;++i)
        for(j=0;j<9;++j)
            weight[i][j]=i-j;

    for(i=0;i<34;++i)
        for(j=0;j<32;++j)
            image[i][j]=i+j;
    //directConvolution(image,34,32,weight,16,9,result,16,32,32);
    //Convolution(image,34,32,weight,16,9,result,16,32,32);

    
    int ready=0;
    int convBuf_image=0;
    int convBuf_weight=0X0100;
    int result_num=0;
    int result_fetch=0X1000;
    printf("start calculating convolution results,please waiting...\n");
    //load the weight 
    for(i=0;i<16;++i)
        for(j=0;j<9;j=j+3)
        {
            uint32_t temp1=weight[i][j];
            uint32_t temp2=weight[i][j+1];
            uint32_t temp3=weight[i][j+2];
            uint32_t temp=temp1+(temp2<<8)+(temp3<<16);
            convBuf(convBuf_weight)=temp;
        }
    //load image and calculating
    //printf("start reading image data\n");
    for(i=0;i<35;++i)
    {   
        int test_value=-1;
        if(ready==0)
            for(j=0;j<32;j=j+4)
            {
                uint32_t temp1=image[i][j];
                uint32_t temp2=image[i][j+1];
                uint32_t temp3=image[i][j+2];
                uint32_t temp4=image[i][j+3];
                uint32_t temp=temp1+(temp2<<8)+(temp3<<16)+(temp4<<24);
                if(i==0) temp=0;
                convBuf(convBuf_image)=temp;
                if(i==2 && j==28)    ready=1;      
            }
        else
        {
            int t=1000;
            while(t>0) {--t;}
            printf(" ");
            int m=0,n=0;
            for(m=0;m<16;++m)
            for(n=0;n<32;++n)
            {
                ++result_num;
                result[m][i-3][n]=convBuf(result_fetch);
                printf("result num:%d-------read convolution result:%d\n",result_num,convBuf(result_fetch));
            
            }
            printf("finish reading convolution result of %d cycle\n",i-2);

            //printf("load new line of image data\n");
            if(i!=34)
                for(j=0;j<32;j=j+4)
                {
                        uint32_t temp1=image[i][j];
                        uint32_t temp2=image[i][j+1];
                        uint32_t temp3=image[i][j+2];
                        uint32_t temp4=image[i][j+3];
                        uint32_t temp=temp1+(temp2<<8)+(temp3<<16)+(temp4<<24);
                        if(i==33) temp=0;
                        convBuf(convBuf_image)=temp;  
                }
        }
    }

    printf("finish reading convolution result of all \n");
    
    return 0;
}
 



void Convolution(int image[][32],int image_m,int imge_n,
                    int weight[][9],int weight_m,int weight_n,
                    int result[][32][32],int result_x,int result_y,int result_z
)
{

    int i=0,j=0;

    //0~47:weight matrix
    int addr=0;
    for(i=0;i<16;++i)
        for(j=0;j<9;j=j+3)
        {
            uint32_t temp1=weight[i][j];
            uint32_t temp2=weight[i][j+1];
            uint32_t temp3=weight[i][j+2];
            //uint32_t temp=temp1+(temp2<<8)+(temp3<<16);
            uint32_t temp=0+(0<<8)+(0<<16)+(0<<24);
            memo(addr)=temp;
            addr=addr+4;
        }
    //48~319:input image matrix
    for(i=0;i<34;++i)
        for(j=0;j<32;j=j+4)
        {
            uint32_t temp1=image[i][j];
            uint32_t temp2=image[i][j+1];
            uint32_t temp3=image[i][j+2];
            uint32_t temp4=image[i][j+3];
            //uint32_t temp=temp1+(temp2<<8)+(temp3<<16)+(temp4<<24);
            uint32_t temp=1+(1<<8)+(1<<16)+(1<<24);
            memo(addr)=temp;
            addr=addr+4;
        }
    // testSRAM();
    // //result:320~4415
    // int m=0;
    // for(m=0;m<16;++m)
    //     for(i=0;i<32;++i)
    //         for(j=0;j<32;j=j+4)
    //         {
    //             uint32_t temp=0+(1<<8)+(2<<16)+(3<<24);
    //             memo(addr)=temp;
    //             addr=addr+4;
    //         }


    // int test_addr=0;

    // for(i=0;i<34;++i)
    // for(j=0;j<32;j=j+4)
    // {
    //     uint32_t temp1=image[i][j];
    //     uint32_t temp2=image[i][j+1];
    //     uint32_t temp3=image[i][j+2];
    //     uint32_t temp4=image[i][j+3];
    //     //uint32_t temp=temp1+(temp2<<8)+(temp3<<16)+(temp4<<24);
    //     uint32_t temp=1+(1<<8)+(1<<16)+(1<<24);
    //     memo(test_addr)=temp;
    //     test_addr=addr+4;
    // }

    // testSRAM();


    int ready=0;
    int convBuf_image=0;
    int convBuf_weight=0X0100;
    int result_num=0;
    int result_fetch=0X1000;
    printf("start calculating convolution results,please waiting...\n");
    //load the weight 
    addr=0;
    for(i=0;i<16;++i)
        for(j=0;j<9;j=j+3)
        {
            uint32_t temp1=weight[i][j];
            uint32_t temp2=weight[i][j+1];
            uint32_t temp3=weight[i][j+2];
            //uint32_t temp=temp1+(temp2<<8)+(temp3<<16);
            uint32_t temp=1+(1<<8)+(1<<16)+(1<<24);
            convBuf(convBuf_weight)=temp;
        }
    //load image and calculating
    printf("start reading image data\n");
    for(i=0;i<35;++i)
    {   
    int test_value=-1;
    if(ready==0)
        for(j=0;j<32;j=j+4)
        {
            uint32_t temp1=image[i][j];
            uint32_t temp2=image[i][j+1];
            uint32_t temp3=image[i][j+2];
            uint32_t temp4=image[i][j+3];
            //uint32_t temp=temp1+(temp2<<8)+(temp3<<16)+(temp4<<24);
            uint32_t temp=1+(1<<8)+(1<<16)+(1<<24);
            if(i==0) temp=0;
            convBuf(convBuf_image)=temp;
            if(i==2 && j==28)    ready=1;      
        }
    else
    {
        int t=1000;
        while(t>0) {--t;}
        printf(" ");
        int m=0,n=0;
        int res;
        for(m=0;m<16;++m)
        for(n=0;n<32;++n)
        {
            ++result_num;
            res=convBuf(result_fetch);
            //printf("result num:%d-------read convolution result:%d\n",result_num,convBuf(result_fetch));
           
        }
        printf("finish reading convolution result of %d cycle\n",i-2);

        //printf("load new line of image data\n");
        if(i!=34)
            for(j=0;j<32;j=j+4)
            {
                    uint32_t temp1=image[i][j];
                    uint32_t temp2=image[i][j+1];
                    uint32_t temp3=image[i][j+2];
                    uint32_t temp4=image[i][j+3];
                    uint32_t temp=temp1+(temp2<<8)+(temp3<<16)+(temp4<<24);
                    if(i==33) temp=0;
                    convBuf(convBuf_image)=temp;  
            }
    }
    }
    printf("finish reading convolution result of all \n");
}

void directConvolution(int image[][32],int image_m,int imge_n,
                        int weight[][9],int weight_m,int weight_n,
                        int result[][32][32],int result_x,int result_y,int result_z
)
{
    int i=0,j=0;
    int ready=0;
    int convBuf_image=0;
    int convBuf_weight=0X0100;
    int result_num=0;
    int result_fetch=0X1000;
    //printf("start calculating convolution results,please waiting...\n");
    //load the weight 
    for(i=0;i<16;++i)
        for(j=0;j<9;j=j+3)
        {
            //printf("finish reading convolution result of %d cycle\n",weight[i][j]);
            uint32_t temp1=weight[i][j];
            uint32_t temp2=weight[i][j+1];
            uint32_t temp3=weight[i][j+2];
            uint32_t temp=temp1+(temp2<<8)+(temp3<<16);
            convBuf(convBuf_weight)=temp;
        }
    //load image and calculating
    //printf("start reading image data\n");
    for(i=0;i<35;++i)
    {   
    int test_value=-1;
    if(ready==0)
        for(j=0;j<32;j=j+4)
        {
            uint32_t temp1=image[i][j];
            uint32_t temp2=image[i][j+1];
            uint32_t temp3=image[i][j+2];
            uint32_t temp4=image[i][j+3];
            uint32_t temp=temp1+(temp2<<8)+(temp3<<16)+(temp4<<24);
            if(i==0) temp=0;
            convBuf(convBuf_image)=temp;
            if(i==2 && j==28)    ready=1;      
        }
    else
    {
        int t=1000;
        while(t>0) {--t;}
        printf(" ");
        int m=0,n=0;
        for(m=0;m<16;++m)
        for(n=0;n<32;++n)
        {
            ++result_num;
            result[m][i-3][n]=convBuf(result_fetch);
            //printf("result num:%d-------read convolution result:%d\n",result_num,convBuf(result_fetch));
           
        }
        printf("finish reading convolution result of %d cycle\n",i-2);

        //printf("load new line of image data\n");
        if(i!=34)
            for(j=0;j<32;j=j+4)
            {
                    uint32_t temp1=image[i][j];
                    uint32_t temp2=image[i][j+1];
                    uint32_t temp3=image[i][j+2];
                    uint32_t temp4=image[i][j+3];
                    uint32_t temp=temp1+(temp2<<8)+(temp3<<16)+(temp4<<24);
                    if(i==33) temp=0;
                    convBuf(convBuf_image)=temp;  
            }
    }
    }
    printf("finish reading convolution result of all \n");
}
void testSRAM()
{
    printf("-------------test convSRAM start---------------\n");
    memo(0)=3;
    int a=memo(0);
    printf("read memo(0):%d\n",a);

    memo(4)=2;
    int b=memo(4);
    printf("read memo(4):%d\n",b);

    int c=memo(0);
    printf("read memo(0):%d\n",c);

}