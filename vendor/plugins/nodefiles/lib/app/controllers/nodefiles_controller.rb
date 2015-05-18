class NodefilesController < InheritedResources::Base

  self.append_view_path(File.join(RAILS_ROOT, "vendor/plugins/nodefiles/lib/app/views"))

  def nodefiles
    @node = Node.find(params[:node_id])
    @node_files = NodeFile.all(:conditions => ["node_id = ?", params[:node_id]])
  end

end
