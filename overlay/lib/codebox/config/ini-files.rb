class IniFileExc < RuntimeError
end

class IniNode
	def initialize(name, value=nil) 
		@line_start = -1
		@line_end = -1
		@level = 0
		@name = name
		@value = value
		@keys = {}
		@keylist = []
		@modified = false
		@deleted = false
	end

	attr_reader :level,:line_start,:line_end,:name,:value,:keylist,:keys,:modified,:deleted
	attr_writer :level,:line_start,:line_end,:name,:value,:keylist,:keys,:modified,:deleted

	def to_str 
		@name.to_s + ' = ' + @value.to_s
	end

	def to_s
		@value.to_s
	end

	def to_i
		@value.to_i
	end

	def to_f
		@value.to_f
	end

	def insert(key, value)
		return false if (@keys.has_key?(key)); 
		node = nil; 
		if (value && ((value.class == IniNode) || (value.class == IniSection)))
			node = value;
		else
			if (@level <= 0)
				node = IniSection.new(key);
			else
				node = IniNode.new(key, value)
			end
		end
		node.line_start = @line_end + 1 if (node.line_start < 0);
		node.level = @level + 1;
		@keys[key] = node;
		@keylist.push(key);
		return true;
	end

	def [](key)
		return @keys[key];
	end

	def []=(key, value)
		rc = insert(key, value);
		@keys[key].value = value;
		@keys[key].modified = true;
		@modified = true;
	end

	def delete(key)
		return false if (! @keys.has_key?(key));
		@keys[key].deleted = true;
		@modified = true;
	end

	def each_key
		@keylist.each do |eachKey|
			yield eachKey
		end
	end
end


class IniSection < IniNode
	def initialize(name)
		super(name);
	end

	def to_str
		return ('[' + @name + ']');
	end
end


class IniFile < IniNode
	def initialize(path, load=true)
		super(path);
		@lines = [];
		reload() if (load);
	end

	def reload
		begin
			input = File.new(@name, "r");
		rescue
			raise;
		else
			prevnode = node = self;
			lineno = 0;
			input.each do |line|
				@lines.push(line);
				parsed_node = parse_line(lineno, line);
				if (parsed_node);
					if (parsed_node.class == IniSection)
						if (parsed_node != node)
							prev_node = node;
							node = parsed_node;
							insert(node.name, node);
							prev_node.line_end = lineno - 1;
						end
					else
						node.insert(parsed_node.name, parsed_node);
					end
				end
				lineno += 1;
			end
			input.close;
			node.line_end = @line_end = lineno - 1;
		end
	end

	def parse_line(lineno, line)
		return nil if (line =~ /^\s*$/); 
		return nil if (line =~ /^\s*#/); 
		return nil if (line =~ /^\s*;/); 
		if (line =~ /^\s*\[\s*(.+)\s*\].*$/)
			rv = IniSection.new($1); 
			rv.line_start = lineno; 
			rv.level = @level + 1; 
			return rv; 
		elsif (line =~ /^\s*(\S?.*[^=\s])\s*=\s*(\S?[^#;]*[^#;\s\n]).*$/)
			rv = IniNode.new($1, $2);
			rv.line_start = rv.line_end = lineno; 
			rv.level = @level + 2; 
			return rv; 
		end 
		return nil; 
	end

	def write
		inserted = {}; 
		@keylist.each do |sect|
			sectnode = @keys[sect]; 
			next if (!sectnode.modified || sectnode.deleted);
			if (sectnode.line_end < 0) 
				@lines.push("\n"); 
				@lines.push(sectnode.to_str + "\n");
			end
			sectnode.keylist.each do |key|
				keynode = sectnode.keys[key];
				next if (!keynode.modified || keynode.deleted);
				if (keynode.line_end < 0)
					if (sectnode.line_end < 0)
						@lines.push(keynode.to_str + "\n");
					else
						idx = sectnode.line_end.to_i;
						inserted[idx] = [] if (! inserted.has_key?(idx));
						inserted[idx].push(keynode.to_str);
					end
				else
					line = @lines[keynode.line_start];
					if (line =~ /^(\s*)(\S?.[^=\s]\s=\s*\S?.+[^#;\s])(\s*[#;].*)$/)
						line = $1 + keynode.to_str + $3 + "\n";
					else 
						line = line.gsub(/^(\s*)(\S?.[^=\s]\s=\s*\S?[^#;]+[^#;\n\s])(.*)$/){ $1 + keynode.to_str + $3};
					end
					@lines[keynode.line_start] = line; 
				end
			end
		end
		deleted = {};
		@keylist.each do |sect|
            sectnode = @keys[sect];
            next  if (!sectnode.deleted && !sectnode.modified);
			if (sectnode.deleted && (sectnode.line_start >= 0) && (sectnode.line_end >= 0) && (sectnode.line_end >= sectnode.line_start))
                for i in sectnode.line_start..sectnode.line_end
                    deleted[i] = true;
                end
            end
            sectnode.keylist.each do |key|
                keynode = sectnode.keys[key];
                next  if (!keynode.deleted);
                deleted[keynode.line_start.to_i] = true if ((keynode.line_start >= 0) && (keynode.line_end >= 0) && (keynode.line_start == keynode.line_end));
            end
		end
		begin
            file = File.new(@name, 'w');
		rescue
            raise(IniFileExc, "Failed to open " + @name + " for writing: #{$!}", caller);
		else
            cnt = -1;
            @lines.each do |line|
                cnt += 1;
                if (inserted.has_key?(cnt))
                    inserted[cnt].each do |ins|
                        file.puts(ins + "\n");
                    end
                end
                next  if (deleted[cnt]);
                file.puts(line)
			end
		end 
	end
end

