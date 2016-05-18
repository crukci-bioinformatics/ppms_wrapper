module PPMS
  module Utilities

    def isAncestor(ancestor,child)
      parent = child.parent_id
      while not parent.nil? and parent != ancestor.id
        child = Project.find(parent)
        parent = child.parent_id
      end
      return (not parent.nil?)
    end

    def reduceProjSet(pset)
      npset = Set.new
      pset.each do |proj|
        hasAncestor = pset.map{|p| isAncestor(p,proj) ? 1 : 0}.sum > 0
        if not hasAncestor
          npset.add(proj)
        end
      end
      return npset
    end

  end
end
