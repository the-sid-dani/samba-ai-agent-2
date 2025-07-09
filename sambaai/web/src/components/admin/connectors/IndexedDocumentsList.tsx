"use client";

import { useState, useEffect } from "react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ChevronDown, ChevronUp, ExternalLink, FileText } from "lucide-react";

interface DocumentSyncStatus {
  doc_id: string;
  last_synced: string | null;
  last_modified: string | null;
}

interface IndexedDocumentsListProps {
  ccPairId: number;
  documentsCount: number;
}

function extractDocumentName(docId: string): string {
  try {
    // Remove the base Confluence URL and extract the meaningful part
    let name = docId
      .replace(/https:\/\/[^\/]+\/wiki\/spaces\/[^\/]+\//, "")
      .replace(/pages\/\d+\//, "")
      .replace(/\+/g, " ")
      .replace(/%20/g, " ");
    
    // If it's just "overview", make it more descriptive
    if (name === "overview") {
      name = "Space Overview";
    }
    
    return name || "Unknown Document";
  } catch {
    return "Unknown Document";
  }
}

export function IndexedDocumentsList({ ccPairId, documentsCount }: IndexedDocumentsListProps) {
  const [documents, setDocuments] = useState<DocumentSyncStatus[]>([]);
  const [isExpanded, setIsExpanded] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchDocuments = async () => {
    if (documents.length > 0) return; // Already fetched
    
    setIsLoading(true);
    setError(null);
    
    try {
      const response = await fetch(`/api/manage/admin/cc-pair/${ccPairId}/get-docs-sync-status`);
      if (!response.ok) {
        throw new Error(`Failed to fetch documents: ${response.statusText}`);
      }
      const data = await response.json();
      setDocuments(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch documents');
    } finally {
      setIsLoading(false);
    }
  };

  const handleToggle = () => {
    if (!isExpanded) {
      fetchDocuments();
    }
    setIsExpanded(!isExpanded);
  };

  return (
    <div className="mt-2">
      <Button
        variant="ghost" 
        size="sm"
        onClick={handleToggle}
        className="p-0 h-auto font-normal text-sm text-blue-600 hover:text-blue-800 hover:bg-transparent"
      >
        <FileText className="h-4 w-4 mr-1" />
        View {documentsCount} indexed documents
        {isExpanded ? (
          <ChevronUp className="h-4 w-4 ml-1" />
        ) : (
          <ChevronDown className="h-4 w-4 ml-1" />
        )}
      </Button>

      {isExpanded && (
        <Card className="mt-3 p-4 max-h-96 overflow-y-auto">
          {isLoading ? (
            <div className="flex items-center justify-center py-4">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
              <span className="ml-2 text-sm text-gray-600">Loading documents...</span>
            </div>
          ) : error ? (
            <div className="text-red-600 text-sm">
              <p>{error}</p>
            </div>
          ) : documents.length === 0 ? (
            <p className="text-gray-500 text-sm">No documents found.</p>
          ) : (
            <div className="space-y-2">
              <div className="flex items-center justify-between mb-3">
                <h4 className="font-medium text-sm">Indexed Documents</h4>
                <Badge variant="secondary" className="text-xs">
                  {documents.length} total
                </Badge>
              </div>
              
              <div className="space-y-2">
                {documents.map((doc, index) => {
                  const documentName = extractDocumentName(doc.doc_id);
                  const lastSynced = doc.last_synced 
                    ? new Date(doc.last_synced).toLocaleDateString()
                    : 'Never';
                  
                  return (
                    <div 
                      key={doc.doc_id}
                      className="flex items-center justify-between p-2 rounded border hover:bg-gray-50"
                    >
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center space-x-2">
                          <FileText className="h-4 w-4 text-gray-400 flex-shrink-0" />
                          <span className="text-sm font-medium truncate">
                            {documentName}
                          </span>
                        </div>
                        <div className="text-xs text-gray-500 mt-1">
                          Last synced: {lastSynced}
                        </div>
                      </div>
                      
                      <a
                        href={doc.doc_id}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex-shrink-0 ml-2 p-1 hover:bg-gray-200 rounded"
                        title="Open document"
                      >
                        <ExternalLink className="h-3 w-3 text-gray-500" />
                      </a>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </Card>
      )}
    </div>
  );
} 