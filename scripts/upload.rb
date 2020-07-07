require "rmega"

def create_path(fullpath,storage)
  paths = fullpath.split("/")

  i=0
  parent_folder=""

  # Iterate over path segments by slash
  paths.each do |path|
    if i == 0
      parent_folder = storage.root
    end

    # Find folders in inode
    inode_id = parent_folder.folders.find { |folder| folder.name == path }

    # Copy id for next iteration or create folder and iterate
    if inode_id != nil
      parent_folder = inode_id
      inode_id=""
    else
      parent_folder = parent_folder.create_folder(path)
    end

    i = i + 1
  end

end

if ARGV.length < 3
  puts "USAGE: ./upload.rb [USERNAME] [PASSWORD] [PATH]"
end

begin
  storage = Rmega.login(ARGV[0].to_s, ARGV[1].to_s)
rescue
  puts "Error - Failed to login"
  exit
end

# Create directory and return parent inode id
create_path(ARGV[2].to_s,storage)
