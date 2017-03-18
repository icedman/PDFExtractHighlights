//
//  main.m
//  PDFExtractHi
//
//  Created by Marvin Sanchez on 03/05/2016.
//  Copyright © 2016 Marvin Sanchez. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

bool extractOnlyUnderline = false;
bool addSeparator = false;
bool doubleSpaced = false;
bool comment = false;
bool showPage = false;
int pageStart = -1;
int pageEnd = -1;

void printColor(float r, float g, float b) {
    
    float w = 2.0f;
    int rr = (int)(255 * (r + w) / 3);
    int gg = (int)(255 * (g + w) / 3);
    int bb = (int)(255 * (b + w) / 3);
    
    rr = rr > 255 ? 255 : rr;
    gg = gg > 255 ? 255 : gg;
    bb = bb > 255 ? 255 : bb;
    
    printf("rgb(%d,%d,%d)", rr,gg,bb);
}

void checkUnderLine(PDFDocument *pdfDoc) {
    long pc = pdfDoc.pageCount;
    for(int i=0;i<pc;i++) {
        
        PDFPage *page = [pdfDoc pageAtIndex:i];
        NSArray *annotations = [page annotations];
        long annotCount = [annotations count];
        
        if (annotCount == 0)
            continue;
        
        for (int j = 0; j < annotCount; j++) {
            PDFAnnotation *annot = [annotations objectAtIndex: j];
            if ([annot.type isEqualToString:@"Underline"]) {
                extractOnlyUnderline = true;
                return;
            }
        }
        
    }
}

void extractPage(PDFPage *page) {
    
//    printf("<style>body { background-color:#000}</style>");
    
    Boolean hasSpan = false;
    Boolean hasDiv = false;
    Boolean prevIn = false;
    Boolean hasBold = false;
    
    int skipLine = 0;
    
    float prevY = 0;
    float minX = -1;
    
    long count = page.numberOfCharacters;
    
    NSArray *annotations = [page annotations];
    long annotCount = [annotations count];
    
    if (annotCount == 0)
        return;

    Boolean underline = false;
    
    NSColor *prevClr = NULL;
    NSColor *fClr = NULL;
    
    NSMutableString *tmp = [NSMutableString string];
    
    float dX = -1;
    float prevDy = 0;
    
    PDFAnnotation *fComment = NULL;
    
    for(int i=0;i<count;i++) {
        NSRect rect = [page characterBoundsAtIndex:i];
        
        NSRect fBounds;
        PDFAnnotation *fAnnot = NULL;
        Boolean inside = false;
        
        Boolean charUnderline = false;
        
        for (int j = 0; j < annotCount; j++) {
            PDFAnnotation *annot = [annotations objectAtIndex: j];
            
            NSRect bounds = [annot bounds];
            
            CGPoint pp = rect.origin;
            pp.x = pp.x + (rect.size.width/2);
            pp.y = pp.y + (rect.size.height/2);
            
            if (CGRectIntersectsRect(bounds, rect) || CGRectContainsPoint(bounds, pp)) {
                if ([annot.type isEqualToString:@"Underline"]) {
                    charUnderline = true;
                    if (extractOnlyUnderline) {
                        inside = true;
                    }
                }
            }

            if (![annot.type isEqualToString:@"Highlight"])
                continue;
             
            
            if (CGRectContainsPoint(bounds, pp)) {
                
                inside = true;
                NSColor *clr = annot.color;
                
                float fArea = fBounds.size.height * fBounds.size.height;
                float area = bounds.size.height * bounds.size.height;
                
                if (fAnnot == NULL || fArea > area) {
                    fAnnot = annot;
                    fBounds = bounds;
                    fClr = clr;
                }
            }
            
        }
        
        float pyy = prevDy - rect.origin.y;
        pyy = (pyy * pyy);
        if (pyy > (10 * 10)) {
            dX = rect.origin.x;
        }
        
        if (rect.origin.x < minX || minX == -1) {
            minX = rect.origin.x;
        }
        
        
        float dY = rect.origin.y - prevY;
        dY = dY * dY;
        int rep = dY/(10*15);
        
        if (doubleSpaced)
            rep = dY/(10*25);
        
        
        char c = [page.string characterAtIndex:i];
        
        if (!inside && prevIn && sqrt(dY) < 10 && c != 32 && c != '.') {
            inside= true;
        }
        
        if (inside || (extractOnlyUnderline && charUnderline)) {
            
            if (extractOnlyUnderline && !charUnderline) {
                skipLine = 1;
                continue;
            }
            
            
            if (c >= 32 && c < 126) {
            } else {
                continue;
            }
            
            if (comment) {
                if (fAnnot != fComment) {
                    fComment = fAnnot;
                    if (fComment.contents.length > 0) {
                        printf("\n<p style='padding:8px; background-color:#f0f0f0'>%s</p>\n", [fComment.contents UTF8String]);
                    }
                }
            }
            
            
            if (rep > 0 && prevY != 0) {
                
                float dXx = (dX - minX)/40.0;
                if (dXx > 2.0) {
                    if (!hasDiv) {
                        printf("<div style='padding-left:40px'>\n");
                        hasDiv = true;
                    }
                } else {
                    
                    if (hasDiv) {
                        printf("</div>\n");
                        hasDiv = false;
                    }
                    
                }
                
                rep--;
                if (rep > 1) {
                    
                    if (hasSpan) {
                        printf("</span>");
                        hasSpan = false;
                    }
                    
                    for(int b=0;b<rep && b<2;b++) {
                        fClr = NULL;
                        printf("<br>\n");
                    }
                } else {
                    printf(" ");
                }

            } else {
                
                if (skipLine > 0) {
                    skipLine = -1;
                    
                    if (hasSpan) {
                        printf("</span>");
                        hasSpan = false;
                    }
                    
                    printf("<br>\n");
                    
                    fClr = NULL;
                } else {
                    
                    if (!prevIn)
                        printf(" ");
                    
                }
            }
            
            if (charUnderline) {
                if (!underline) {
                    if (addSeparator)
                        printf("\n<hr>\n");
                    underline = true;
                }
            } else {
                underline = false;
            }
            
            if (prevClr != fClr && fClr != NULL) {
                if (hasSpan)
                    printf("</span>");
                
                if (hasBold)
                    printf("</b>");
                
                printf("<span style='background-color:");
                if (fClr != NULL) {
                    printColor([fClr redComponent],[fClr greenComponent],[fClr blueComponent]);
                }
                printf("'>");
                
                hasSpan = true;
            }
            
            
            if (fClr == NULL) {
                [tmp appendFormat:@"%c", c];
            } else {
                
                if ([tmp length] > 0) {
                    printf("%s", [tmp cStringUsingEncoding:NSASCIIStringEncoding]);
                    [tmp setString:@""];
                }
                
                printf("%c", c);
            }
            
            
            prevClr = fClr;
            prevY = rect.origin.y;
            
            skipLine = -1;
            
        } else {
            
            fClr = NULL;
            
            if (skipLine != -1)
                skipLine++;
        }
        
        prevIn = inside;
        if (skipLine > 1)
            prevIn = false;
        prevDy = rect.origin.y;
    }
    
    //putchar('\n');
    if (hasSpan)
        printf("</span>");
    
    if (hasDiv)
        printf("</div>\n");
    
}

void extract(NSString *path) {
    
    NSURL *url = [NSURL fileURLWithPath:path];
    PDFDocument *pdfDoc = [PDFDocument alloc];
    pdfDoc = [pdfDoc initWithURL:url];
    
    if (pdfDoc == NULL) {
        NSLog(@"unable to load %@", path);
        return;
    }
    
//    if (!extractOnlyUnderline && !addSeparator)
//        checkUnderLine(pdfDoc);
    
    long pc = pdfDoc.pageCount;
    for(int i=0;i<pc;i++) {
        if (pageStart != -1 && i+1 < pageStart)
            continue;
        if (pageEnd != -1 && i+1 > pageEnd)
            break;
        PDFPage *page = [pdfDoc pageAtIndex:i];
        
        if (showPage) {
            printf("<h2>Page %d</h2>", i+1);
        }

        extractPage(page);
    }
    
    printf("\n");
    
}

void showHelp()
{
    printf("PDFExtractHi [options] filename\n");
    printf("\noptions:\n");
    printf("  -underline\textract only underlined highlights\n");
    printf("  -comment\tprint out highlight comment\n");
    printf("  -page\t\tdisplay page number\n");
    printf("  -start\tspecify starting page\n");
    printf("  -end\t\tspecify ending page\n");
    printf("\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        if (argc > 1) {
            
            if (argc > 2) {
                for(int i=1;i<argc-1;i++) {
                    NSString *arg = [NSString stringWithFormat:@"%s", argv[i]];
                    //NSLog(@"<<%@>>", arg);
                    
                    if ([arg containsString:@"-help"]) {
                        showHelp();
                        return 0;
                    }
                    
                    if ([arg containsString:@"-underline"]) {
                        extractOnlyUnderline = true;
                    }
                    
                    if ([arg containsString:@"-separator"]) {
                        addSeparator = true;
                    }
                    
                    if ([arg containsString:@"-double"]) {
                        doubleSpaced = true;
                    }
                    
                    if ([arg containsString:@"-comment"]) {
                        comment = true;
                    }
                    
                    if ([arg containsString:@"-page"]) {
                        showPage = true;
                    }
                    
                    if ([arg containsString:@"-start"]) {
                        i++;
                        arg = [NSString stringWithFormat:@"%s", argv[i]];
                        if (i < argc-1) {
                            pageStart = [arg intValue];
                        }
                        continue;
                        
                    }
                    if ([arg containsString:@"-end"]) {
                        i++;
                        arg = [NSString stringWithFormat:@"%s", argv[i]];
                        if (i < argc-1) {
                            pageEnd = [arg intValue];
                        }
                        continue;
                        
                    }
                }
            }
            
            
            NSString *path = [NSString stringWithFormat:@"%s", argv[argc-1]];
            //path = @"/Users/iceman/Desktop/t.pdf";
            
            if (addSeparator) {
                extractOnlyUnderline = false;
                printf("\n<hr>\n");
            }
            extract(path);
            printf("\n<br><br>\n");
            
        } else {
            showHelp();
        }
        
    }
    
    //printf("%d %d\n", pageStart, pageEnd);
    
    return 0;
}
