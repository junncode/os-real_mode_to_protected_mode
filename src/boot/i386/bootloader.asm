org	0x7c00                  ;
[BITS 16]

START:   
mov     ax, 0xb800          ;배경 지우기
mov     es, ax
mov     ax, 0
mov     di, ax
mov     cx, 80*20*2
rep stosd

call    PrintSelectScreen   ;커널 선택 화면 출력

mov     ax, 1               ;ssuos_1로 초기화
mov     [partition_num], ax
call    PrintCurSelect

call    Keyboard_Int        ;키보드 인터럽트 실행

jmp     BOOT1_LOAD          ;부트로더 실행

BOOT1_LOAD:     ;boot1 읽어오는 함수
	    mov     ax, 0x0900  ;복사 목적지 주소 값 지정 es:bx = 0x0900:0000(물리주소: 0x09000)
        mov     es, ax
        mov     bx, 0x0

                ;LBA = (실린더 x 실린더당 헤드 개수(16) x 섹터 개수(63)) + (헤드 x 섹터 개수(63)) + 섹터 -1

        mov     ah, 2	    ;0x13 인터럽트 호출 시 ah에 저장된 값에 따라 수행되는 결과가 다르다, 2섹터 읽기
        mov     al, 0x4		;al: 읽을 섹터 수를 지정 1~128 사이의 값을 지정 가능
        mov     ch, 0	    ;실린더 번호; cl의 상위 2비트까지 사용가능 하여 표현
        mov     cl, 2	    ;읽기 시작할 섹터의 번호; 1~18사이의 값, 1에는 부트로더가 있으니 2 이상부터
        mov     dh, 0		;일기 시작할 헤드 번호; 1~15값
        mov     dl, 0x80    ;드라이브 번호; 0x00: 플로피, 0x80: 첫번째 하드, 0x81: 두번째 하드
                ;LBA = 0

        int     0x13	    ;읽기 인터럽트 호출
        jc      BOOT1_LOAD  ;에러 발생시 다시 시도

KERNEL_LOAD:    ;SSUOS_1 kernel 읽어오는 함수
        xor      si, si
        mov     ax, 1                   ;partition_num에 따라 다르게 Load
        cmp     [partition_num], ax
        je      .SSUOS1_LOAD
        
        mov     ax, 2
        cmp     [partition_num], ax
        je      .SSUOS2_LOAD
        
        mov     ax, 3
        cmp     [partition_num], ax
        je      .SSUOS3_LOAD
        
    .SSUOS1_LOAD:
	    mov     ax, 0x1000	;es:bx = 0x1000:0000 (물리주소: 0x100000)
        mov     es, ax		
        mov     bx, 0x0		;0x10000 번지에 커널 로드

        mov     ah, 2		;디스크에 있는 데이터 es:bx의 주소로 / ah = 2 : 섹터 읽기
        mov     al, 0x3f	;0x3f 섹터를 읽을 것이다. / 0x3f 크기 만큼 읽을것이다
        mov     ch, 0		;실린더 번호: 0 ;0번째 실린더
        mov     cl, 0x6	    ;섹터 번호: 0x6 ;0x6번째 섹터부터 읽기 시작
        mov     dh, 0       ;헤드 번호: 0 ;head = 0
        mov     dl, 0x80    ;drive = 0x80 드라이브
                ;LBA = 6

        int     0x13        ;읽기 인터럽트
        jc      .SSUOS1_LOAD ;에러날 경우 다시 실행
        jmp		0x0900:0x0000       ;kernel.bin이 있는곳으로?

    .SSUOS2_LOAD:
	    mov     ax, 0x1000	;es:bx = 0x1000:0000 (물리주소: 0x100000)
        mov     es, ax		
        mov     bx, 0x0		;0x10000 번지에 커널 로드

        mov     ah, 2		;디스크에 있는 데이터 es:bx의 주소로 / ah = 2 : 섹터 읽기
        mov     al, 0x3f	;0x3f 섹터를 읽을 것이다. / 0x3f 크기 만큼 읽을것이다
        mov     ch, 0x9		;실린더 번호: 9
        mov     cl, 0x2f      ;섹터 번호: 47
        mov     dh, 0xe      ;헤드 번호: 14
        mov     dl, 0x80    ;drive = 0x80 드라이브
                ;LBA = 10000

        int     0x13        ;읽기 인터럽트
        jc      .SSUOS2_LOAD ;에러날 경우 다시 실행
        jmp		0x0900:0x0000       ;kernel.bin이 있는곳으로?

    .SSUOS3_LOAD:
	    mov     ax, 0x1000	;es:bx = 0x1000:0000 (물리주소: 0x100000)
        mov     es, ax		
        mov     bx, 0x0		;0x10000 번지에 커널 로드

        mov     ah, 2		;디스크에 있는 데이터 es:bx의 주소로 / ah = 2 : 섹터 읽기
        mov     al, 0x3f	;0x3f 섹터를 읽을 것이다. / 0x3f 크기 만큼 읽을것이다
        mov     ch, 0xe		;실린더 번호: 14
        mov     cl, 0x7     ;섹터 번호: 7
        mov     dh, 0xe     ;헤드 번호: 14
        mov     dl, 0x80    ;drive = 0x80 드라이브
                ;LBA = 15000

        int     0x13        ;읽기 인터럽트
        jc      .SSUOS3_LOAD ;에러날 경우 다시 실행
        jmp		0x0900:0x0000       ;BOOT1 주소


;함수 파트
PrintString:                    ;문자열 출력하는 함수
    push    ax                  ;원래 ax레지스터 값 스택에 저장
    mov     ax, 0xb800      
    mov     es, ax              ;비디오 모드
    mov     ah, 0x07            ;글자 색
    .loop:
        mov     al, [si]
        cmp     al, 0           ;끝났는지 검사
        je      .endFunc

        mov     [es:di], ax
        add     si, 1           ;글자 순서 + 1
        add     di, 2           ;물리주소 + 2
        jmp     .loop
.endFunc:
    pop     ax
    ret

PrintSelectScreen:      ;kernel 선택 default 화면
    push    si

    mov     di, 0
    mov     si, ssuos_1
    call    PrintString

    add     di, 3*2
    mov     si, ssuos_2
    call    PrintString

    add     di, 55*2
    mov     si, ssuos_3
    call    PrintString

    pop     si
    ret

PrintCurSelect:                         ;select 출력
        mov     si, select

        mov     ax, 1                   ;partition_num에 따라 다르게 Print
        cmp     [partition_num], ax
        je      .loc1
        mov     ax, 2
        cmp     [partition_num], ax
        je      .loc2
        mov     ax, 3
        cmp     [partition_num], ax
        je      .loc3
    .loc1:
        mov     di, 0
        jmp     .print
    .loc2:
        mov     di, 14*2
        jmp     .print
    .loc3:
        mov     di, 80*2
        jmp     .print
    .print:
        call    PrintString
        ret

Keyboard_Int:                   ;키보드 인터럽트 함수
    push    ax
    .loop:
        xor     ax, ax
        mov     ah, 0x00
        int     0x16            ;키보드 인터럽트 실행

        cmp     ah, 0x1c        ;enter 키
        je      .endFunc
        cmp     ah, 0x4b        ;left
        je      .leftKey
        cmp     ah, 0x4d        ;right
        je      .rightKey
        cmp     ah, 0x48        ;top
        je      .topKey
        cmp     ah, 0x50        ;down
        je      .downKey
        jmp     .loop
.leftKey:
    mov     ax, 2
    cmp     [partition_num], ax
        jne      .loop
    mov     ax, 1
    mov     [partition_num], ax
    jmp     .print

.rightKey:
    mov     ax, 1
    cmp     [partition_num], ax
        jne     .loop
    mov     ax, 2
    mov     [partition_num], ax
    jmp     .print

.topKey:
    mov     ax, 3
    cmp     [partition_num], ax
        jne     .loop
    mov     ax, 1
    mov     [partition_num], ax
    jmp     .print

.downKey:
    mov     ax, 1
    cmp     [partition_num], ax
        jne     .loop
    mov     ax, 3
    mov     [partition_num], ax
    jmp     .print

.print:                             ;select가 바뀌면 실행
    call    PrintSelectScreen
    call    PrintCurSelect
    jmp     .loop

.endFunc:
    pop     ax
    ret

;변수 파트
select db "[O]",0
ssuos_1 db "[ ] SSUOS_1",0
ssuos_2 db "[ ] SSUOS_2",0
ssuos_3 db "[ ] SSUOS_3",0
ssuos_4 db "[ ] SSUOS_4",0
partition_num : resw 1

times   446-($-$$) db 0x00

PTE:
partition1 db 0x80, 0x00, 0x00, 0x00, 0x83, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x3f, 0x0, 0x00, 0x00
partition2 db 0x80, 0x00, 0x00, 0x00, 0x83, 0x00, 0x00, 0x00, 0x10, 0x27, 0x00, 0x00, 0x3f, 0x0, 0x00, 0x00
partition3 db 0x80, 0x00, 0x00, 0x00, 0x83, 0x00, 0x00, 0x00, 0x98, 0x3a, 0x00, 0x00, 0x3f, 0x0, 0x00, 0x00
partition4 db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
times 	510-($-$$) db 0x00
dw	0xaa55
