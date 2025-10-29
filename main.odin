package main

import "core:fmt"
import "core:time/datetime"
import "core:strconv"
import "core:time"
import "core:os"
import "core:strings"
MAX_CHAR_PER_LINE :: 60
config_path:: "/home/vidof/work/projects/chst/config/jrnl.txt"

TOP_BAR    :: "┌─────────────────────────────────────────────────────────────┐"
BOTTOM_BAR :: "└─────────────────────────────────────────────────────────────┘"
SPACES_19:: "                   "

E_TIME_MEASURE:: enum{
	YEAR,  MONTH, DAY,
	HOUR, MINUTE, SECOND
}

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


note_write:: proc(note: A_Note)
{
	content := note_format(note)
	fd, err := os.open(config_path, os.O_WRONLY | os.O_APPEND, 0o664)
	if err != os.ERROR_NONE 
	{
		fmt.eprintf("ERROR OPENING CHEST: %v", err)
		os.exit(1)
	}

	n: int
	n, err = os.write_string(fd, content)

	if err != os.ERROR_NONE 
	{
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
	ap(&sb, fmt.tprintf("%v,%02d\n%v", date_formated(note), n, formated_content))
	
	return strings.to_string(sb)
}

content_formated:: proc(content: string)-> (lines_n: int, val: string)
{
	n := 0
	sb: strings.Builder
	ap := strings.write_string

	length_content := len(content)
    for n < length_content 
	{
        end := n + MAX_CHAR_PER_LINE

		spaces := ""
		index_space := 0
        if end > length_content {
			spaces = get_n_chars(end-length_content, ' ')
            end = length_content
        } 
		else 
		{
			index_space = get_char_index_reverse(content[n:end], ' ')
			end -= index_space
			spaces = get_n_chars(index_space, ' ')
		}

        ap(&sb, fmt.tprintf("%v%v\n", content[n:end], spaces))
        n += MAX_CHAR_PER_LINE-index_space
		lines_n += 1
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
	if len(os.args)==1 do CMD_default()

	switch os.args[1]{
		case "-h", "--help":
			fmt.println(`
			Usage:
				chst [command] [arguments]

			Commands:
				-h, --help
					Show this help message and exit.

				-gl, --get_last <n>
					Get the last <n> journal entries.
					Example: jrnl --get_last 5

				-g, --get <filters...>
					Get entries filtered by time-based queries.
					Each filter must follow one of these patterns:
						d<day>     - filter by day (e.g. d12 for 12th day)
						m<month>   - filter by month number (e.g. m11 for November)
						y<year>    - filter by year (e.g. y2025)
						h<hour>    - filter by hour (e.g. h14 for 2PM)
						min<min>   - filter by minute (e.g. min30)
						s<second>  - filter by second (e.g. s45)
					Example:
						jrnl --get y2025 m10 d29
					(Filters can be combined.)`)

		case "-gl", "--get_last":
			if len(os.args) == 3 
			{
				n, _ := strconv.parse_int(os.args[2])
				notes_get_last(n)
				fmt.println("GOOD")
				os.exit(0)
			} 
			else
			{
				fmt.eprintf("Not enough arguments for %v", os.args[1])
				os.exit(1)
			}
		case "-g", "--get":
			// "d12"
			// "y2025"
			// "m12"
			// "h"
			// "min"
			// "s"
			if len(os.args) >= 3 
			{
				fmt.println("WE START")
				queries := make(map[E_TIME_MEASURE]string)
				for arg in os.args[2:]
				{
					kind, val := parse_get_argument(arg)
					queries[kind] = val
				}
				fmt.println("QUERIES: ", queries)
				note_print_by_query(queries)
			} 
			else
			{
				fmt.eprintf("Not enough arguments for %v", os.args[1])
				os.exit(1)
			}


		case:
			fmt.eprintf("WHAT THE HELL IS EVEN THAT %v", os.args[1])
	}
}

note_print_by_query:: proc(queries: map[E_TIME_MEASURE]string)
{
	data, ok := os.read_entire_file_from_filename(config_path, allocator = context.temp_allocator)

	if !ok {
		fmt.eprintf("Could not open chest file %v.", config_path)
		os.exit(1)
	}
	
	s_data := strings.split_lines(string(data))
	if len(s_data) < 3 do return
	for i:=2; i < len(s_data); 
	{
		if strings.starts_with(s_data[i], "[") 
		{
			should_print := true

			if len(s_data[i]) != 24 do continue
			for k, v in queries
			{
				switch k
				{
					case .YEAR:
						if v != s_data[i][1:5] do should_print = false
					case .MONTH:
						if v != s_data[i][6:8] do should_print = false
					case .DAY:
						if v != s_data[i][9:11] do should_print = false
					case .HOUR:
						if v != s_data[i][12:14] do should_print = false
					case .MINUTE:
						if v != s_data[i][15:17] do should_print = false
					case .SECOND:
						if v != s_data[i][18:20] do should_print = false


				}

			}

			num_lines_note, ok := strconv.parse_int(s_data[i][len(s_data[i])-2:]) 
			if !ok {
				fmt.eprintln("Line n %v, was not correctly formated", i)
				return
			}
			if should_print do lines_print(s_data[i:i+num_lines_note+1])

			i += num_lines_note+1
			// WE WRITE s_data[i:i+num_lines]
		} 
		else
		{
			i += 1
			continue
		}

	}
}


parse_get_argument:: proc(arg: string)->(kind: E_TIME_MEASURE, val: string)
{
	if len(arg)<2 do return 
	ok: bool
	switch arg[0]
	{
	case 'y':
		kind = .YEAR
		val = arg[1:]
		
		
	case 'm':
		if arg[1]!='i'
		{
			kind = .MONTH
			val = arg[1:]
		}
		else
		{
			kind = .MINUTE
			val = arg[3:]
		}
	case 'd':
		kind = .DAY
		val = arg[1:]
	case 'h':
		kind = .HOUR
		val = arg[1:]
	case 's':
		kind = .SECOND
		val = arg[1:]
	}
	return
}


CMD_default:: proc()
{
	if !os.exists(config_path) 
	{
		name := input("No config file found. Put a name to your chest")
		chest_new(config_path, name)
	}

	val := input("Tell me something:\n>")
	note := note_new_now(val)
	note_write(note)
	os.exit(0)
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

	ap(&sb, fmt.tprintf("[%04d,%02d,%02d,%02d,%02d,%02d]", note.created_on.year, note.created_on.month, note.created_on.day, note.created_on.hour, note.created_on.minute, note.created_on.second))
	
	return strings.to_string(sb)
}

date_formated_datetime :: proc(date: Date)->string
{
	sb: strings.Builder
	ap := strings.write_string

	ap(&sb, fmt.tprintf("[%04d,%02d,%02d,%02d,%02d,%02d]", date.year, date.month, date.day, date.hour, date.minute, date.second))
	
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

notes_get_last:: proc(n: int)
{
	note: A_Note
	note_p := 0
	count := 0

	data, ok := os.read_entire_file_from_filename(config_path, allocator = context.temp_allocator)
	if !ok
	{
		fmt.eprintf("ERROR reading file %v", config_path)
		os.exit(1)
	}
	file := string(data)

	split_lines := strings.split_lines(file)
	#reverse for line, i in split_lines
	{
		if strings.trim(line, " ") == "" do continue
		if strings.starts_with(line, "[") && len(line)>21
		{
			fmt.println(TOP_BAR)
			fmt.printf("│%v%v%v  │\n", SPACES_19, line[:21], SPACES_19)
			trimed := strings.trim(line, " ")
			length := len(trimed)

			num_lines, _:= strconv.parse_int(trimed[length-2:])


			start:= i+1
			end := num_lines + start
			for n in start..<end
			{
				fmt.printf("│%v│\n", split_lines[n])
			}
			fmt.println(BOTTOM_BAR)

			count += 1
			if count >= n do break
		} 
	}
	
	if count < n do	fmt.printfln("We found just %d in your chest", count)
}


lines_print:: proc(lines: []string)
{
	fmt.println(TOP_BAR)
	fmt.printf("│%v%v%v  │\n", SPACES_19, lines[0][:21], SPACES_19)
	for line in lines[1:] do fmt.printf("│%v│\n", line)
	fmt.println(BOTTOM_BAR)
}

parse_note_header::proc(data:string)->(vals: [7]int)
{
	date_trim := strings.trim(data, "[ ")

	n:= 0
	for val in strings.split_iterator(&date_trim, ",") {
		vals[n], _ = strconv.parse_int(val)
		n+=1
	}

	length := len(date_trim)

	vals[6], _= strconv.parse_int(date_trim[length-2:])
	fmt.println("I PARSED IT LIKETHIS: ", vals[6])
	return 
}

out:: proc(){if true do os.exit(1)}
