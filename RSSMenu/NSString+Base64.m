#import "NSString+Base64.h"

@implementation NSString (Base64)

static char *alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";  

- (NSString *)base64EncodedString {  
    
    NSData *plainText = [self dataUsingEncoding:NSUTF8StringEncoding];
    
    unsigned long encodedLength = (((([plainText length] % 3) + [plainText length]) / 3) * 4) + 1;  
    unsigned char *outputBuffer = malloc(encodedLength);  
    unsigned char *inputBuffer = (unsigned char *)[plainText bytes];  
    
    NSInteger i;  
    NSInteger j = 0;  
    unsigned long remain;
    
    for(i = 0; i < [plainText length]; i += 3) {  
        remain = [plainText length] - i;  
        
        outputBuffer[j++] = alphabet[(inputBuffer[i] & 0xFC) >> 2];  
        outputBuffer[j++] = alphabet[((inputBuffer[i] & 0x03) << 4) |   
                                     ((remain > 1) ? ((inputBuffer[i + 1] & 0xF0) >> 4): 0)];  
        
        if(remain > 1)  
            outputBuffer[j++] = alphabet[((inputBuffer[i + 1] & 0x0F) << 2)  
                                         | ((remain > 2) ? ((inputBuffer[i + 2] & 0xC0) >> 6) : 0)];  
        else   
            outputBuffer[j++] = '=';  
        
        if(remain > 2)  
            outputBuffer[j++] = alphabet[inputBuffer[i + 2] & 0x3F];  
        else  
            outputBuffer[j++] = '=';              
    }  
    
    outputBuffer[j] = 0;  
    
    NSString *result = [NSString stringWithCString:(const char *)outputBuffer encoding:NSUTF8StringEncoding];  
    free(outputBuffer);  
    
    return result;  
}  

@end  
