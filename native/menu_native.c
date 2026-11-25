#define COBJMACROS
#include <windows.h>
#include <wincodec.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <wchar.h>

static HMODULE module;
static wchar_t root[32768];
static volatile LONG busy;
static void init(void){
 if(root[0])return;
 GetModuleFileNameW(module,root,32768);
 for(int i=0;i<3;i++){wchar_t *p=wcsrchr(root,L'\\');if(p)*p=0;}
 wchar_t state[32768];swprintf(state,32768,L"%ls\\state",root);CreateDirectoryW(state,0);
 swprintf(state,32768,L"%ls\\state\\paint",root);CreateDirectoryW(state,0);
}
static BYTE *read_png(IWICImagingFactory *f,const wchar_t *path,UINT *w,UINT *h){
 IWICBitmapDecoder *d=0;IWICBitmapFrameDecode *frame=0;IWICFormatConverter *c=0;BYTE *pixels=0;
 if(FAILED(IWICImagingFactory_CreateDecoderFromFilename(f,path,0,GENERIC_READ,WICDecodeMetadataCacheOnLoad,&d)))goto done;
 if(FAILED(IWICBitmapDecoder_GetFrame(d,0,&frame))||FAILED(IWICBitmapFrameDecode_GetSize(frame,w,h))||!*w||!*h||*w>1024||*h>1024)goto done;
 if(FAILED(IWICImagingFactory_CreateFormatConverter(f,&c)))goto done;
 if(FAILED(IWICFormatConverter_Initialize(c,(IWICBitmapSource*)frame,&GUID_WICPixelFormat32bppRGBA,WICBitmapDitherTypeNone,0,0,WICBitmapPaletteTypeCustom)))goto done;
 pixels=malloc(*w**h*4);if(pixels&&FAILED(IWICFormatConverter_CopyPixels(c,0,*w*4,*w**h*4,pixels))){free(pixels);pixels=0;}
 done:if(c)IWICFormatConverter_Release(c);if(frame)IWICBitmapFrameDecode_Release(frame);if(d)IWICBitmapDecoder_Release(d);return pixels;
}
static int write_png(IWICImagingFactory *f,const wchar_t *path,BYTE *pixels,UINT w,UINT h){
 IWICStream *s=0;IWICBitmapEncoder *e=0;IWICBitmapFrameEncode *frame=0;IPropertyBag2 *props=0;int ok=0;
 if(FAILED(IWICImagingFactory_CreateStream(f,&s))||FAILED(IWICStream_InitializeFromFilename(s,path,GENERIC_WRITE)))goto done;
 if(FAILED(IWICImagingFactory_CreateEncoder(f,&GUID_ContainerFormatPng,0,&e))||FAILED(IWICBitmapEncoder_Initialize(e,(IStream*)s,WICBitmapEncoderNoCache)))goto done;
 if(FAILED(IWICBitmapEncoder_CreateNewFrame(e,&frame,&props))||FAILED(IWICBitmapFrameEncode_Initialize(frame,props)))goto done;
 WICPixelFormatGUID fmt=GUID_WICPixelFormat32bppBGRA;
 if(FAILED(IWICBitmapFrameEncode_SetSize(frame,w,h))||FAILED(IWICBitmapFrameEncode_SetPixelFormat(frame,&fmt)))goto done;
 for(UINT i=0;i<w*h*4;i+=4){BYTE r=pixels[i];pixels[i]=pixels[i+2];pixels[i+2]=r;}
 if(FAILED(IWICBitmapFrameEncode_WritePixels(frame,h,w*4,w*h*4,pixels)))goto done;
 ok=SUCCEEDED(IWICBitmapFrameEncode_Commit(frame))&&SUCCEEDED(IWICBitmapEncoder_Commit(e));
 done:if(props)IPropertyBag2_Release(props);if(frame)IWICBitmapFrameEncode_Release(frame);if(e)IWICBitmapEncoder_Release(e);if(s)IWICStream_Release(s);return ok;
}
static int safe_name(const char *s){size_t n=strlen(s);if(!n||n>64)return 0;for(;*s;s++)if(!((*s>='a'&&*s<='z')||(*s>='0'&&*s<='9')||*s=='-'))return 0;return 1;}
static DWORD WINAPI render_job(void *unused){
 wchar_t file[32768];swprintf(file,32768,L"%ls\\state\\paint-request.txt",root);
 FILE *in=_wfopen(file,L"rb");IWICImagingFactory *factory=0;HRESULT co=CoInitializeEx(0,COINIT_MULTITHREADED);int count=0,failed=0;
 if(!in||FAILED(CoCreateInstance(&CLSID_WICImagingFactory,0,CLSCTX_INPROC_SERVER,&IID_IWICImagingFactory,(void**)&factory)))goto done;
 unsigned r,g,b,revision;char name[80];
 if(fscanf(in,"%u %u %u %u",&r,&g,&b,&revision)!=4||r>255||g>255||b>255)goto done;
 double color[3]={r/255.0,g/255.0,b/255.0};
 while(count<64&&fscanf(in,"%79s",name)==1){
  if(!safe_name(name)){failed++;continue;}
  wchar_t base[80],black[32768],white[32768],dest[32768],temp[32768];MultiByteToWideChar(CP_UTF8,0,name,-1,base,80);
  swprintf(black,32768,L"%ls\\assets\\cars\\%ls-black.png",root,base);swprintf(white,32768,L"%ls\\assets\\cars\\%ls-white.png",root,base);
  swprintf(dest,32768,L"%ls\\state\\paint\\%ls-v%u-%02x%02x%02x.png",root,base,revision,r,g,b);swprintf(temp,32768,L"%ls.tmp",dest);
  UINT w=0,h=0,ww=0,hh=0;BYTE *a=read_png(factory,black,&w,&h),*z=read_png(factory,white,&ww,&hh);count++;
  if(!a||!z||w!=ww||h!=hh){free(a);free(z);failed++;continue;}
  for(UINT i=0;i<w*h*4;i+=4){
   /* The black render preserves glass, tires, lighting and reflections. Only
      the measured painted-body difference receives the selected color. */
   int difference=0;for(int c=0;c<3;c++)difference+=max(0,(int)z[i+c]-a[i+c]);
   if(difference>24)for(int c=0;c<3;c++){
    double low=pow(a[i+c]/255.0,2.2),high=pow(z[i+c]/255.0,2.2);
    double v=low+color[c]*max(0.0,high-low);a[i+c]=(BYTE)min(255,max(0,(int)(pow(v,1/2.2)*255+.5)));
   }
  }
  if(write_png(factory,temp,a,w,h))MoveFileExW(temp,dest,MOVEFILE_REPLACE_EXISTING);else failed++;
  free(a);free(z);
 }
 done:if(in)fclose(in);if(factory)IWICImagingFactory_Release(factory);if(SUCCEEDED(co))CoUninitialize();
 wchar_t complete[32768];swprintf(file,32768,L"%ls\\state\\paint-done.tmp",root);swprintf(complete,32768,L"%ls\\state\\paint-done.txt",root);
 FILE *out=_wfopen(file,L"wb");if(out){fprintf(out,"%d %d",count,failed);fclose(out);}InterlockedExchange(&busy,0);if(out)MoveFileExW(file,complete,MOVEFILE_REPLACE_EXISTING);return 0;
}
__declspec(dllexport) int bm_render(void *state){
 init();if(InterlockedCompareExchange(&busy,1,0))return 0;
 HANDLE h=CreateThread(0,0,render_job,0,0,0);if(h)CloseHandle(h);else InterlockedExchange(&busy,0);return 0;
}
/* Read the game's own client-area pointer. Never send input or capture screens. */
__declspec(dllexport) int bm_pointer(void *state){
 init();HWND h=GetForegroundWindow();DWORD pid=0;GetWindowThreadProcessId(h,&pid);POINT p={0};RECT r={0};int focus=pid==GetCurrentProcessId();
 if(focus){GetCursorPos(&p);ScreenToClient(h,&p);GetClientRect(h,&r);}
 wchar_t path[32768];swprintf(path,32768,L"%ls\\state\\pointer.txt",root);FILE *f=_wfopen(path,L"wb");
 if(f){fprintf(f,"%d %.9f %.9f",focus,r.right?(double)p.x/r.right:0,r.bottom?(double)p.y/r.bottom:0);fclose(f);}return 0;
}
BOOL WINAPI DllMain(HINSTANCE h,DWORD reason,LPVOID reserved){if(reason==DLL_PROCESS_ATTACH){module=h;DisableThreadLibraryCalls(h);}return TRUE;}
