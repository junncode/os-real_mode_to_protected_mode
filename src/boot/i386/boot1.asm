org	0x9000                      ;BOOT1_LOAD 주소

[BITS 16]                       ;이 프로그램이 16비트 단위로 데이터를 처리하는 프로그램이라는 뜻이다.

		cli		                ; Clear Interrupt Flag, 인터럽트 플래그를 초기화한다.

		mov     ax, 0xb800          
        mov     es, ax          ;es에 0xb800 할당, 0xb8000 -> 비디오 메모리 물리주소
        mov     ax, 0x00
        mov     bx, 0
        mov     cx, 80*25*2     ;화면 크기, 80: 줄 글자 수, 25: 줄 수, 2: 글자 바이트 수
CLS:                            ;배경 지우기
        mov     [es:bx], ax     ;ax = 0이므로 화면을 다 0으로, 아무것도 출력안함
        add     bx, 1
        loop    CLS             ;cx만큼 반복한다.
 
Initialize_PIC:                 ;PIC = programmable interrupt controller
                                ;0x20 = Master PIC Command (mpc)
                                ;0x21 = Master PIC Data (mpd)
                                ;0xa0 = Slave PIC Command (spc)
                                ;0xa1 = Slave PIC Data (spd)

		;ICW1 - 두 개의 PIC를 초기화 
		mov		al, 0x11        ;al = 0x11 (00010001)
                                ;LTIM(3) = 0 - 0:엣지 트리거링, 1: 레벨 트리거링
                                ;SNGL(1) = 0 - 0:마스터 슬레이브 구조, 1: 마스터만 사용
                                ;IC4(0) = 1
		out		0x20, al        ;mpc
		out		0xa0, al        ;spc

		;ICW2 - 발생된 인터럽트 번호에 얼마를 더할지 결정
               ;PIC의 IQR의 시작점 설정 (IRQ 리맵핑)
               ;이 PIC가 인터럽트를 받았을 때 IRQ 번호에 얼마를 더해서 CPU에 알려줄지 정함
               ;0-2비트를 0으로 설정해 숫자를 8 단위로 기재
		mov		al, 0x20        ;0x20 (00100000)
		out		0x21, al        ;mpd
                                ;IRQ 8 부터 시작 함으로, 마스터PIC + 8 을 세트
		mov		al, 0x28        ;0x28 (00101000) => 0x20 + 8의 값
		out		0xa1, al        ;spd
               ;만약 IRQ 0에 연결된 하드웨어에서 인터럽트가 발생한다면
               ;IRQ는 0x20이 된다.

		;ICW3 - 마스터/슬레이브 연결 핀 정보 전달
               ;마스터PIC와 슬레이브PIC의 구분
                                ;(S7 S6 S5 S4 S3 S2 S1 S0) - 각 IRQ선에 해당
                                ;                          - 0: 하드웨어 장치에 연결
                                ;                          - 1: 슬레이브 PIC에 연결
                                ;( 0  0  0 0 0 ID2 ID1 ID0) - ID0~ID2 3비트를 사용하여
                                ; 슬레이브 PIC이 마스터PIC의 몇 번 IRQ 핀에 연결되어 있는지 세트
		mov		al, 0x04        ;0x04 (00000100)
		out		0x21, al        ;mpd
		mov		al, 0x02        ;0x02 (00000010)
		out		0xa1, al        ;spd
                                ;마스터PIC의 IRQ 2번에 슬레이브PIC 연결

		;ICW4 - 기타 옵션 
		mov		al, 0x01        ;0x01 (uPM = 1 - 8086 모드)
		out		0x21, al
		out		0xa1, al
                            
		mov		al, 0xFF        ;인터럽트 막기    
		;out		0x21, al
		out		0xa1, al        ;슬레이브PIC이 연결된 IRQ 2번 핀을 제외한 인터럽트를 막는다
        ;mov    al, 0xFB
        ;out    0x21, al

Initialize_Serial_port:
		xor		ax, ax          ;ax 0으로 초기화
		xor		dx, dx          ;dx 0으로 초기화
		mov		al, 0xe3        ;al = 0xe3
		int		0x14            ;ah가 0일 때 인터럽트 14 = dx를 포트 번호로 직렬 포트를 초기화한다
                                ;리턴: ah = 라인 상태, al = 모뎀 상태
READY_TO_PRINT:
		xor		si, si          ;출력 준비를 한다
		xor		bh, bh
PRINT_TO_SERIAL:        
		mov		al, [msgRMode+si]       ;'Real Mode'
		mov		ah, 0x01
		int		0x14                    ;ah = 0x1, int = 0x14 => 문자열을 전송한다
		add		si, 1
		cmp		al, 0                   ;문자열 끝났는지 검사
		jne		PRINT_TO_SERIAL         ;끝나지 않았으면 반복
PRINT_NEW_LINE:                         ;'\n\r' 출력
		mov		al, 0x0a
		mov		ah, 0x01
		int		0x14                    ;'\n' 한줄 내리기
		mov		al, 0x0d
		mov		ah, 0x01
		int		0x14                    ;'\r' carriage return = 커서 맨 앞으로 옮기기

; OS assignment 2
; add your code here
; print current date to boch display


Activate_A20Gate:               ;BIOS 콜로 A20 Gate 켜기
		mov		ax,	0x2401      ;0x2400: disable, 0x2401: able
		int		0x15            ;

;Detecting_Memory:
;		mov		ax, 0xe801
;		int		0x15

PROTECTED:                      ;보호모드 진입하는 부분
        xor		ax, ax          ;ax 초기화
        mov		ds, ax          ;ds 초기화    

		call	SETUP_GDT       ;lgdt레지스터에 gdt를 등록시키는 함수 호출
        ;cr0 레지스터 설정 (CPU에게 이제 Protected Mode로 넘어간다고 알림)
        mov		eax, cr0        ;cr0의 0bit - 1:Protected Mode, 0: Real Mode
        or		eax, 1	        ;cr0의 다른 비트에게 영향을 끼치지 않게 or 연산
        mov		cr0, eax  
        
        ;CPU 파이프라인 유닛 비우기
        ;Protected Mode로 변경되었으나
        ;CPU에는 파이프라이닝으로 인해 16비트 명령어 코드가 남아있을 수 있다.
        ;jmp를 이용해 CPU의 16비트 코드를 깨끗히 지운다.
		jmp		$+2             ;현재 주소 + 2
		nop                     ;의도적으로 delay 유발
		nop
		jmp		CODEDESCRIPTOR:ENTRY32      ;0x08:Entry32

SETUP_GDT:          ;lgdt 레지스터에 gdt를 등록시켜 CPU가 사용할 수 있도록 해야된다.
		lgdt	[GDT_DESC]
		ret

[BITS 32]                           ;이 프로그램이  32비트 단위로 데이터를 처리하는 프로그램이라는 뜻

ENTRY32:
		mov		ax, 0x10            ;보호모드 커널용 DATADESCRIPTOR를 ax 레지스터에 저장
		mov		ds, ax              ;ds 세그먼트 셀렉터에 설정
		mov		es, ax              ;es         //
		mov		fs, ax              ;fs         //
		mov		gs, ax              ;gs         //

        ;스택을 0x00000000 ~ 0x0000FFFF 영역에 64KB 크기로 생성
		mov		ss, ax              ;ss         //
  		mov		esp, 0xFFFE         ;esp 레지스터의 address를 0xFFFE로 설정
		mov		ebp, 0xFFFE	        ;ebp                //

		mov		edi, 80*2           ;edi에 80글자 만큼의 바이트 입력
		lea		esi, [msgPMode]     ;esi에 msgPMode의 주소값을 입력한다.    
		call	PRINT               ;PRINT함수 호출

		;IDT TABLE
	    cld                         ;directin 플래그를 0으로 만들어준다.
		mov		ax,	IDTDESCRIPTOR
		mov		es, ax
		xor		eax, eax
		xor		ecx, ecx
		mov		ax, 256
		mov		edi, 0
 
IDT_LOOP:
		lea		esi, [IDT_IGNORE]
		mov		cx, 8
		rep		movsb
		dec		ax
		jnz		IDT_LOOP

		lidt	[IDTR]

		sti
		jmp	CODEDESCRIPTOR:0x10000

PRINT:                                  ;문자열 print 시작
		push	eax                     ;레지스터에 있던 값을 스택에 보존해 둔다.
		push	ebx                     ;                   //
		push	edx                     ;                   //
		push	es                      ;                   //
		mov		ax, VIDEODESCRIPTOR        
		mov		es, ax                  ;es에 VIDEODESCRIPTOR 주소 복사해두기
PRINT_LOOP:
		or		al, al                  ;al이 0인지 확인 (문자열이 끝났는지 확인)
		jz		PRINT_END               ;0이라면 PRINT_END로 점프
		mov		al, byte[esi]           ;esi가 가리키는 주소에서 문자를 하나 가져옴
		mov		byte [es:edi], al       ;문자를 화면에 나타냄
		inc		edi                     ;edi값을 1 증가 시킨다
		mov		byte [es:edi], 0x07     ;문자의 색과 배경색의 값을 넣는다
OUT_TO_SERIAL:
		mov		bl, al                  ;al값 bl에 저장
		mov		dx, 0x3fd               ;0x3fd는 LSR로 Line Status Register이다.
CHECK_LINE_STATUS:
		in		al, dx                  ;포트로 부터 데이터 입력
		and		al, 0x20                ;and 연산
		cmp		al, 0                   ;al이 0인지 검사
		jz		CHECK_LINE_STATUS       ;같다면 다시실행
		mov		dx, 0x3f8               ;0x3f8은 RBR로 Receiver Buffer Registe이다.
		mov		al, bl                  ;bl에 있던 원래 al값 가져오기
		out		dx, al                  ;포트로 부터 데이터 출력

		inc		esi                     ;다음 문자를 꺼내기 위해 esi를 하나 증가시킨다
		inc		edi                     ;화면에 다음 문자를 나타내기 위해 edi를 증가시킨다
		jmp		PRINT_LOOP              ;루프를 돈다

PRINT_END:                              ;출력 마무리 함수
LINE_FEED:                              ;한줄 내리기 함수
		mov		dx, 0x3fd               ;LSR(Line Status Register)
		in		al, dx
		and		al, 0x20
		cmp		al, 0                   ;line status가 0x20하고 and연산 했을 때 0인지 검사
		jz		LINE_FEED               ;시리얼에 데이터를 출력할 수 있을때 까지 대기
		mov		dx, 0x3f8               
		mov		al, 0x0a
		out		dx, al                  ;포트로 부터 데이터 출력
CARRIAGE_RETURN:                        ;커서 맨 앞으로 이동시키는 함수
		mov		dx, 0x3fd
		in		al, dx
		and		al, 0x20                ;0x3fd & 0x20 하는 것은
		cmp		al, 0                   ;시리얼에 데이터를 출력할 수 있을때 까지 대기하는 것
		jz		CARRIAGE_RETURN         
		mov		dx, 0x3f8
		mov		al, 0x0d
		out		dx, al                  ;데이터 출력!

		pop		es
		pop		edx
		pop		ebx
		pop		eax                     ;스택에 보존해둔 레지스터들을 다시 꺼낸다.
		ret                             ;호출한 부분으로 돌아간다.

GDT_DESC:               ;GDTR 레지스터: GDT가 어디에, 몇 개나 있는지 저장하고 있는 레지스터 
                        ;0-15비트: 사용할 수 있는 GDT의 크기
                        ;16-47비트: GDT의 시작점 주소를 저장
        dw GDT_END - GDT - 1    ;GDT_END: gdt의 끝, GDT: gdt의 위치, 0부터 시작함으로 1을 뺀다.
        dd GDT          ;+0x10000(커널의 베이스 어드레스) ?
                        ;GDTR에는 세그먼트:오프셋이 아니라 물리주소를 넣어야한다

GDT:                    ;GDT에는 NULL, 코드 세그먼트, 데이터 세그먼트 디스크립터가 있어야한다.
		NULLDESCRIPTOR equ 0x00
			dw 0        ;limit 0-15
			dw 0        ;base 0-15
			db 0        ;base 16-23
			db 0        ;type, s, DPL, P
			db 0        ;limit 16-19, AVL, 0, D, G
			db 0        ;base  24-63
		CODEDESCRIPTOR  equ 0x08
			dw 0xffff   ;limit 0-15         
			dw 0x0000   ;base 0-15           
			db 0x00     ;base 16-23  (0x01 ?)         
			db 0x9a     ;10011010(2)  - 코드 세그먼트라는 것을 알 수 있다, DPL = 0을 알 수 있다.
			db 0xcf     ;11001111(2)
			db 0x00     ;base 24-63
		DATADESCRIPTOR  equ 0x10
			dw 0xffff   ;limit 0-15
			dw 0x0000   ;base 0-15
			db 0x00     ;base 16-23
			db 0x92     ;10010010(2) - 데이터 세그먼트이고, 읽기/쓰기가 가능하다
			db 0xcf     ;11001111(2)
			db 0x00     ;base 24-63
		VIDEODESCRIPTOR equ 0x18
			dw 0xffff              
			dw 0x8000              
			db 0x0b     
			db 0x92     ;10010010(2)
			db 0x40     ;10000000(2) - G = 0 : 세그먼트의 크기가 바이트 단위로 지정이 되었다.
			;db 0xcf                    
			db 0x00                 
		IDTDESCRIPTOR	equ 0x20
			dw 0xffff
			dw 0x0000
			db 0x02
			db 0x92
			db 0xcf
			db 0x00
GDT_END:
IDTR:
		dw 256*8-1
		dd 0x00020000
IDT_IGNORE:
		dw ISR_IGNORE
		dw CODEDESCRIPTOR
		db 0
		db 0x8E
		dw 0x0000
ISR_IGNORE:
		push	gs
		push	fs
		push	es
		push	ds
		pushad
		pushfd
		cli
		nop
		sti
		popfd
		popad
		pop		ds
		pop		es
		pop		fs
		pop		gs
		iret



msgRMode db "Real Mode", 0          ;문자열 변수 선언 부분
msgPMode db "Protected Mode", 0

 
times 	2048-($-$$) db 0x00         ;남은 부분 0으로 채우기
