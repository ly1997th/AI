struct Data
{   
    int nRow[8];
};




int main()
{  
    Data data[3];

    FILE *fp = fopen("1.txt","rb");  
    if (fp == NULL)
    {
        printf("can not open file!\n");
        exit(0);
    }
    for(int i = 0;i < 3;i ++)
    {
        int nRes = fscanf(fp,"%d，%d，%d，%d，%d，%d，%d，%d，",&data[i].nRow[0],&data[i].nRow[1],&data[i].nRow[2],
            &data[i].nRow[3],&data[i].nRow[4],&data[i].nRow[5],&data[i].nRow[6],&data[i].nRow[7]);
        if (nRes == -1)
        {
            fclose(fp);
        }
    }
    fclose(fp);

    fp = fopen("2.txt","w+");  
    if (fp == NULL)
    {
        printf("can not open file!\n");
        exit(0);
    }

    for (int i = 0;i < 3;i ++)
    {
        char czBuf[100] = {0};
        sprintf(czBuf,"%02d，%02d，%02d，%02d，\n%02d，%02d，%02d，%02d，\n",data[i].nRow[0],data[i].nRow[1],data[i].nRow[2],
            data[i].nRow[3],data[i].nRow[4],data[i].nRow[5],data[i].nRow[6],data[i].nRow[7]);

        fwrite(czBuf,strlen(czBuf),1,fp);
    }
    fclose(fp);

    return 0;
}
