package main

import "core:fmt"
import "core:time/datetime"
import "core:time"
import "core:os"
import "core:strings"
MAX_CHAR_PER_LINE :: 60

config_path:: "./config/jrnl.txt"

Date :: datetime.DateTime
A_Header :: struct
{
	created_on: struct
	{
		year: i64,
		month: i8,
		day: i8,
		hour: i8,
		minute: i8,
		second: i8, },
	owner: string,
	count_notes: u32,
}

A_Note :: struct
{
	created_on: struct
	{
		year: i64,
		month: i8,
		day: i8,
		hour: i8,
		minute: i8,
		second: i8,
	},
	content: string
}

note_get:: proc(from:= 0, to:= 0)->[]A_Note
{
	return {}
}

note_write:: proc(note: A_Note)
{
	content := note_format(note)
	fd, err := os.open(config_path, os.O_WRONLY | os.O_APPEND, 0o664)
	if err != os.ERROR_NONE {
		fmt.eprintf("ERROR OPENING CHEST: %v", err)
		os.exit(1)
	}

	n: int
	n, err = os.write_string(fd, content)

	if err != os.ERROR_NONE {
		fmt.eprintf("ERROR WRITTING NEW NOTE: %v", err)
		os.exit(1)
	}
}

note_new_now:: proc(content: string)-> A_Note
{
	date, ok := time.time_to_datetime(time.now())
	assert(ok)

	return A_Note{
		created_on = 
		{
			day = date.day,
			month = date.month,
			year = date.year,
			hour = date.hour,
			minute = date.minute,
			second = date.second,
		},
		content = content
	}
}

note_format:: proc(note: A_Note)-> string
{
	sb: strings.Builder
	ap:= strings.write_string

	n, formated_content := content_formated(note.content)
	ap(&sb, fmt.tprintf("%v,%v\n%v", date_formated(note), n, formated_content))
	
	return strings.to_string(sb)
}

content_formated:: proc(content: string)-> (n: int, val: string)
{
	sb: strings.Builder
	ap:= strings.write_string

	length_content := len(content)
	fmt.println("THE LENGTH IS ", length_content)
    for n < length_content 
	{
        end := n + MAX_CHAR_PER_LINE

		spaces := ""
		index_space := 0
        if end > length_content {
            end = length_content
        } 
		else 
		{
			index_space = get_char_index_reverse(content[n:end], ' ')
			end -= index_space
			spaces = get_n_chars(MAX_CHAR_PER_LINE-index_space, ' ')
		}

        ap(&sb, fmt.tprintf("%v%v\n", content[n:end], spaces))
        n += MAX_CHAR_PER_LINE-index_space
    }

	val = strings.to_string(sb)
	return
}

get_n_chars:: proc(n: int, char: u8)-> string
{
	sb: strings.Builder
	ap:= strings.write_byte
	for i in 0..=n
	{
		ap(&sb, char)
	}
	return strings.to_string(sb)
}
get_char_index_reverse:: proc(line: string, char: rune)-> (index: int = -1)
{
	index = 0
	#reverse for c in line
	{
		if c == char
		{
			break
		}
		index += 1
	}
	return 
}



main:: proc()
{

	if !os.exists(config_path) 
	{
		name := input("No config file found. Put a name to your chest")
		// path := input(fmt.tprintf("Tell my a path for your chest. Default is %v", config_path))
		chest_new(config_path, name)
	}

	val := input("Tell me something:\n>")
	note := note_new_now(val)
	note_write(note)
}



chest_new :: proc(path: string, name: string)
{
	fd, err := os.open(config_path,  os.O_CREATE | os.O_APPEND | os.O_WRONLY, 0o664)
	defer os.close(fd)
	if err != os.ERROR_NONE
	{
		fmt.eprintf("Not able to create config path in %v, error: %v", config_path, err)
		os.exit(1)
	}

	header := header_new(name)

	n: int
	n, err = os.write_string(fd, header)
	if err != os.ERROR_NONE
	{
		fmt.eprintf("Not able to write to %v, error: %v", config_path, err)
		os.exit(1)
	}
}



// [yyyy,mm,dd,hh,mm,ss]
// CHESTNAME-COUT 
header_new:: proc(name: string)-> string
{
	sb: strings.Builder
	ap := strings.write_string

	date, ok := time.time_to_datetime(time.now())

	ap(&sb, date_formated(date))
	ap(&sb, fmt.tprintf("\n%v,0\n", name))

	return strings.to_string(sb)
}

date_formated :: proc 
{
	date_formated_a_note,
	date_formated_datetime
}

date_formated_a_note :: proc(note: A_Note)->string
{
	sb: strings.Builder
	ap := strings.write_string

	ap(&sb, fmt.tprintf("[%v,%v,%v,%v,%v,%v]", note.created_on.year, note.created_on.month, note.created_on.day, note.created_on.hour, note.created_on.minute, note.created_on.second))
	
	return strings.to_string(sb)
}

date_formated_datetime :: proc(date: Date)->string
{
	sb: strings.Builder
	ap := strings.write_string

	ap(&sb, fmt.tprintf("[%v,%v,%v,%v,%v,%v]", date.year, date.month, date.day, date.hour, date.minute, date.second))
	
	return strings.to_string(sb)
}



input :: proc(prompt: string) -> (val: string)  {
    buffer: [512]u8

    fmt.println(prompt)
    n, err := os.read(os.stdin, buffer[:]) 

    if err != os.ERROR_NONE {
        fmt.eprintln("Error reading input:", err)
        os.exit(1)
    }

	val = strings.clone_from_bytes(buffer[:n], context.allocator)
	val = strings.trim_right(val, "\n")
	return val
}



out:: proc(){if true do os.exit(1)}
